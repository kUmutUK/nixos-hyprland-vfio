#include <QApplication>
#include <QCloseEvent>
#include <QAbstractItemView>
#include <QHeaderView>
#include <QDir>
#include <QFile>
#include <QFileInfo>
#include <QFrame>
#include <QDialog>
#include <QHBoxLayout>
#include <QJsonArray>
#include <QJsonDocument>
#include <QJsonObject>
#include <QLabel>
#include <QMainWindow>
#include <QMessageBox>
#include <QPlainTextEdit>
#include <QPointer>
#include <QProcess>
#include <QProcessEnvironment>
#include <QPushButton>
#include <QStringList>
#include <QStatusBar>
#include <QTimer>
#include <QTableWidget>
#include <QTableWidgetItem>
#include <QVBoxLayout>
#include <QWidget>


namespace {
const QString kAppName = QStringLiteral("NixOS Kernel Manager");
const QString kDefaultFlake = QStringLiteral("/etc/nixos/nixos");
const QString kKernelAttribute =
    QStringLiteral("nixosConfigurations.nixos.config.boot.kernelPackages.kernel");

QString flakeDirectory()
{
    const QString configured = qEnvironmentVariable("NIXOS_CONFIG_FLAKE", kDefaultFlake);
    return QDir::cleanPath(configured);
}

QString readFile(const QString &path)
{
    QFile file(path);
    if (!file.open(QIODevice::ReadOnly | QIODevice::Text))
        return {};
    return QString::fromUtf8(file.readAll());
}

QString runReadOnly(const QString &program, const QStringList &arguments, int timeoutMs = 6000)
{
    QProcess process;
    QProcessEnvironment environment = QProcessEnvironment::systemEnvironment();
    environment.insert(QStringLiteral("SYSTEMD_PAGER"), QStringLiteral("cat"));
    environment.insert(QStringLiteral("SYSTEMD_COLORS"), QStringLiteral("0"));
    process.setProcessEnvironment(environment);
    process.setProcessChannelMode(QProcess::MergedChannels);
    process.start(program, arguments);

    if (!process.waitForStarted(2000))
        return QStringLiteral("Could not start %1: %2").arg(program, process.errorString());
    if (!process.waitForFinished(timeoutMs)) {
        process.kill();
        process.waitForFinished();
        return QStringLiteral("%1 did not finish within %2 seconds.")
            .arg(program)
            .arg(timeoutMs / 1000);
    }

    const QString output = QString::fromLocal8Bit(process.readAll()).trimmed();
    if (process.exitStatus() != QProcess::NormalExit || process.exitCode() != 0) {
        return output.isEmpty()
            ? QStringLiteral("%1 exited with status %2.").arg(program).arg(process.exitCode())
            : output;
    }
    return output.isEmpty() ? QStringLiteral("No entries reported.") : output;
}

QString shellQuote(QString value)
{
    value.replace(QStringLiteral("'"), QStringLiteral("'\\''"));
    return QStringLiteral("'") + value + QStringLiteral("'");
}

QPlainTextEdit *makeOutputPane(QWidget *parent = nullptr)
{
    auto *output = new QPlainTextEdit(parent);
    output->setReadOnly(true);
    output->setLineWrapMode(QPlainTextEdit::NoWrap);
    output->setObjectName(QStringLiteral("outputPane"));
    output->setMinimumHeight(280);
    output->setPlaceholderText(QStringLiteral("Nothing to display yet."));
    return output;
}
} // namespace

class KernelManagerWindow final : public QMainWindow {
public:
    KernelManagerWindow()
        : flakeDir(flakeDirectory())
    {
        setWindowTitle(kAppName);
        setMinimumSize(760, 520);
        resize(920, 590);
        setStyleSheet(styleSheetText());

        buildWindow();
        statusBar()->showMessage(QStringLiteral("NixOS declarative kernel management"));
        QTimer::singleShot(0, this, [this]() { refreshState(); });
        // Show the desktop window before the graphical Polkit agent asks for authentication.
        QTimer::singleShot(150, this, [this]() { startPolkitSession(); });
    }

protected:
    void closeEvent(QCloseEvent *event) override
    {
        if (currentPrivilegedAction == QStringLiteral("update-cachyos") ||
            currentPrivilegedAction == QStringLiteral("rebuild-switch")) {
            QMessageBox::information(
                this, QStringLiteral("Operation still running"),
                QStringLiteral("Wait for the privileged operation to finish before closing Kernel Manager."));
            event->ignore();
            return;
        }
        QProcess *sessionProcess = polkitSessionProcess;
        if (sessionProcess && sessionProcess->state() != QProcess::NotRunning) {
            if (polkitSessionReady) {
                sessionProcess->write("exit\n");
                sessionProcess->waitForBytesWritten(500);
            }
            if (!sessionProcess->waitForFinished(1500)) {
                sessionProcess->terminate();
                if (!sessionProcess->waitForFinished(1000))
                    sessionProcess->kill();
            }
        }
        QMainWindow::closeEvent(event);
    }

private:
    QString flakeDir;
    QString runningKernelRelease;
    QString bootEntriesText = QStringLiteral("Waiting for graphical administrator authorization…");
    QString generationsText = QStringLiteral("Waiting for graphical administrator authorization…");

    QTableWidget *kernelTable = nullptr;
    QLabel *kernelInventoryStatus = nullptr;
    QLabel *runningKernelLabel = nullptr;
    QLabel *inputRevisionLabel = nullptr;
    QLabel *authorizationStatus = nullptr;
    QProcess *polkitSessionProcess = nullptr;
    QProcess *kernelEvaluationProcess = nullptr;
    QPointer<QDialog> operationDialog;
    QPointer<QPlainTextEdit> operationOutput;
    QString polkitOutputBuffer;
    QString currentPrivilegedAction;
    bool polkitSessionReady = false;
    bool privilegedRequestPending = false;
    bool capturingBootEntries = false;
    bool capturingGenerations = false;

    static QString styleSheetText()
    {
        return QStringLiteral(R"(
            QWidget {
                background: #25292f;
                color: #e8ebef;
                font-family: "Inter", "Noto Sans", sans-serif;
                font-size: 13px;
            }
            QLabel#introTitle {
                color: #f4f6f8;
                font-size: 19px;
                font-weight: 700;
            }
            QLabel#mutedText {
                color: #aeb6c1;
            }
            QLabel#sectionTitle {
                color: #dce2e9;
                font-size: 13px;
                font-weight: 650;
            }
            QLabel#statusText {
                color: #aeb6c1;
                font-size: 12px;
            }
            QTableWidget#kernelTable {
                background: #1e2228;
                alternate-background-color: #252a31;
                color: #e8ebef;
                border: 1px solid #424a55;
                border-radius: 5px;
                gridline-color: transparent;
                selection-background-color: #168bd2;
                selection-color: #ffffff;
            }
            QTableWidget#kernelTable::item {
                padding: 7px 9px;
                border-bottom: 1px solid #303740;
            }
            QHeaderView::section {
                background: #343a42;
                color: #dce2e9;
                padding: 8px 9px;
                border: none;
                border-right: 1px solid #424a55;
                border-bottom: 1px solid #4a535f;
                font-weight: 600;
            }
            QPushButton {
                background: #373e47;
                color: #e7ebf0;
                border: 1px solid #4a535f;
                border-radius: 5px;
                padding: 7px 12px;
                min-height: 27px;
                font-weight: 550;
            }
            QPushButton:hover {
                background: #424b56;
                border-color: #65717f;
            }
            QPushButton:pressed {
                background: #2c323a;
            }
            QPushButton#primaryButton {
                background: #167fbd;
                border-color: #2999d8;
                color: #ffffff;
                font-weight: 650;
            }
            QPushButton#primaryButton:hover {
                background: #2194d4;
            }
            QPlainTextEdit#outputPane {
                background: #1b1f25;
                color: #dce2e9;
                border: 1px solid #424a55;
                border-radius: 5px;
                padding: 9px;
                selection-background-color: #168bd2;
                font-family: "JetBrains Mono", "DejaVu Sans Mono", monospace;
                font-size: 12px;
            }
            QStatusBar {
                background: #20242a;
                color: #aeb6c1;
                border-top: 1px solid #3c444e;
            }
            QFrame#separator {
                color: #414953;
                background: #414953;
                max-height: 1px;
            }
            QDialog {
                background: #25292f;
            }
        )");
    }

    void buildWindow()
    {
        auto *central = new QWidget(this);
        auto *layout = new QVBoxLayout(central);
        layout->setContentsMargins(22, 18, 22, 14);
        layout->setSpacing(11);

        auto *title = new QLabel(QStringLiteral("NixOS Kernel Manager"), central);
        title->setObjectName(QStringLiteral("introTitle"));
        layout->addWidget(title);

        auto *description = new QLabel(
            QStringLiteral("View the kernel selected by your NixOS Flake. Update its source, build it, "
                           "or activate the system using the actions below."),
            central);
        description->setObjectName(QStringLiteral("mutedText"));
        description->setWordWrap(true);
        layout->addWidget(description);

        auto *kernelHeading = new QLabel(QStringLiteral("Configured kernel"), central);
        kernelHeading->setObjectName(QStringLiteral("sectionTitle"));
        layout->addWidget(kernelHeading);

        kernelTable = new QTableWidget(0, 4, central);
        kernelTable->setObjectName(QStringLiteral("kernelTable"));
        kernelTable->setHorizontalHeaderLabels(QStringList{
            QStringLiteral("Kernel"), QStringLiteral("Version"),
            QStringLiteral("Category"), QStringLiteral("Status")
        });
        kernelTable->verticalHeader()->hide();
        kernelTable->horizontalHeader()->setSectionResizeMode(0, QHeaderView::Stretch);
        kernelTable->horizontalHeader()->setSectionResizeMode(1, QHeaderView::ResizeToContents);
        kernelTable->horizontalHeader()->setSectionResizeMode(2, QHeaderView::ResizeToContents);
        kernelTable->horizontalHeader()->setSectionResizeMode(3, QHeaderView::ResizeToContents);
        kernelTable->setSelectionBehavior(QAbstractItemView::SelectRows);
        kernelTable->setSelectionMode(QAbstractItemView::SingleSelection);
        kernelTable->setEditTriggers(QAbstractItemView::NoEditTriggers);
        kernelTable->setAlternatingRowColors(true);
        kernelTable->setShowGrid(false);
        kernelTable->setMinimumHeight(86);
        kernelTable->setMaximumHeight(126);
        layout->addWidget(kernelTable);

        kernelInventoryStatus = new QLabel(QStringLiteral("Reading the Flake-selected kernel…"), central);
        kernelInventoryStatus->setObjectName(QStringLiteral("mutedText"));
        kernelInventoryStatus->setWordWrap(true);
        layout->addWidget(kernelInventoryStatus);

        auto *systemRow = new QHBoxLayout();
        runningKernelLabel = new QLabel(QStringLiteral("Running kernel: detecting…"), central);
        runningKernelLabel->setObjectName(QStringLiteral("statusText"));
        inputRevisionLabel = new QLabel(QStringLiteral("CachyOS source: checking…"), central);
        inputRevisionLabel->setObjectName(QStringLiteral("statusText"));
        systemRow->addWidget(runningKernelLabel, 1);
        systemRow->addWidget(inputRevisionLabel, 0, Qt::AlignRight);
        layout->addLayout(systemRow);

        authorizationStatus = new QLabel(
            QStringLiteral("Waiting for graphical administrator authorization…"), central);
        authorizationStatus->setObjectName(QStringLiteral("statusText"));
        authorizationStatus->setWordWrap(true);
        layout->addWidget(authorizationStatus);

        auto *separator = new QFrame(central);
        separator->setObjectName(QStringLiteral("separator"));
        separator->setFrameShape(QFrame::HLine);
        separator->setFrameShadow(QFrame::Plain);
        layout->addWidget(separator);

        auto *buttonRow = new QHBoxLayout();
        buttonRow->setSpacing(7);

        auto *systemInfoButton = new QPushButton(QStringLiteral("System info"), central);
        connect(systemInfoButton, &QPushButton::clicked, this, [this]() { showSystemInformation(); });
        buttonRow->addWidget(systemInfoButton);

        auto *flakeButton = new QPushButton(QStringLiteral("Flake config"), central);
        connect(flakeButton, &QPushButton::clicked, this, [this]() { showFlakeConfiguration(); });
        buttonRow->addWidget(flakeButton);

        auto *refreshButton = new QPushButton(QStringLiteral("Refresh"), central);
        connect(refreshButton, &QPushButton::clicked, this, [this]() {
            refreshState();
            if (polkitSessionReady)
                sendPrivilegedRequest(QStringLiteral("inspect-system"));
            else
                startPolkitSession();
        });
        buttonRow->addWidget(refreshButton);

        buttonRow->addStretch();

        auto *updateButton = new QPushButton(QStringLiteral("Update source"), central);
        connect(updateButton, &QPushButton::clicked, this, [this]() { updateFlakeInput(); });
        buttonRow->addWidget(updateButton);

        auto *buildButton = new QPushButton(QStringLiteral("Build kernel"), central);
        connect(buildButton, &QPushButton::clicked, this, [this]() { buildKernelOnly(); });
        buttonRow->addWidget(buildButton);

        auto *switchButton = new QPushButton(QStringLiteral("Rebuild & switch"), central);
        switchButton->setObjectName(QStringLiteral("primaryButton"));
        connect(switchButton, &QPushButton::clicked, this, [this]() { rebuildAndSwitch(); });
        buttonRow->addWidget(switchButton);

        layout->addLayout(buttonRow);
        layout->addStretch(1);

        setCentralWidget(central);
        setStatusBar(new QStatusBar(this));
    }

    void refreshState()
    {
        const QString flake = readFile(flakeDir + QStringLiteral("/flake.nix"));
        const QString lock = readFile(flakeDir + QStringLiteral("/flake.lock"));

        runningKernelRelease = runReadOnly(
            QStringLiteral("uname"), {QStringLiteral("-r")}, 2500);
        runningKernelLabel->setText(
            QStringLiteral("Running kernel: %1").arg(runningKernelRelease));

        QString revision = QStringLiteral("unknown");
        const QJsonDocument document = QJsonDocument::fromJson(lock.toUtf8());
        if (document.isObject()) {
            const QJsonObject nodes = document.object().value(QStringLiteral("nodes")).toObject();
            const QJsonObject kernel = nodes.value(QStringLiteral("cachyos-kernel")).toObject();
            revision = kernel.value(QStringLiteral("locked")).toObject()
                           .value(QStringLiteral("rev")).toString(QStringLiteral("unknown"));
        }
        inputRevisionLabel->setText(
            QStringLiteral("CachyOS source: %1").arg(revision.left(12)));
        inputRevisionLabel->setToolTip(revision);

        if (flake.isEmpty() || lock.isEmpty()) {
            kernelTable->setRowCount(1);
            setKernelCell(0, 0, QStringLiteral("Flake unavailable"));
            setKernelCell(0, 1, QStringLiteral("—"));
            setKernelCell(0, 2, QStringLiteral("NixOS Flake"));
            setKernelCell(0, 3, QStringLiteral("Unavailable"));
            kernelInventoryStatus->setText(
                QStringLiteral("Both flake.nix and flake.lock must be readable in %1.").arg(flakeDir));
            statusBar()->showMessage(QStringLiteral("Flake files are missing or unreadable"), 6000);
            return;
        }

        const bool knownProfile =
            flake.contains(QStringLiteral("rtBoreLtoV3KernelPackagesFor config.kumutuk.host.kernelKcfi"));
        const QString name = knownProfile
            ? QStringLiteral("CachyOS RT-Bore-LTO")
            : QStringLiteral("Flake-selected kernel");
        const QString category = flake.contains(QStringLiteral("processorOpt = \"x86_64-v3\""))
            ? QStringLiteral("x86-64-v3")
            : QStringLiteral("NixOS Flake");

        kernelTable->setRowCount(1);
        setKernelCell(0, 0, name);
        setKernelCell(0, 1, QStringLiteral("Evaluating…"));
        setKernelCell(0, 2, category);
        setKernelCell(0, 3, QStringLiteral("Configured"));
        kernelTable->setRowHeight(0, 35);
        kernelInventoryStatus->setText(
            QStringLiteral("Kernel selection stays in the Flake. Build and system activation are separate."));
        statusBar()->showMessage(QStringLiteral("Kernel configuration refreshed"), 4000);

        startKernelEvaluation();
    }

    void setKernelCell(int row, int column, const QString &value)
    {
        auto *item = new QTableWidgetItem(value);
        if (column == 3)
            item->setTextAlignment(Qt::AlignCenter);
        kernelTable->setItem(row, column, item);
        if (row == 0)
            kernelTable->setRowHeight(0, 35);
    }

    void startKernelEvaluation()
    {
        if (kernelEvaluationProcess)
            return;

        auto *process = new QProcess(this);
        kernelEvaluationProcess = process;
        process->setProcessChannelMode(QProcess::MergedChannels);

        connect(process, &QProcess::finished, this,
                [this, process](int exitCode, QProcess::ExitStatus exitStatus) {
            const QString output = QString::fromLocal8Bit(process->readAll()).trimmed();
            if (kernelEvaluationProcess == process)
                kernelEvaluationProcess = nullptr;
            process->deleteLater();

            if (exitStatus != QProcess::NormalExit || exitCode != 0 || output.isEmpty() ||
                output.contains(QStringLiteral("error:"))) {
                setKernelCell(0, 1, QStringLiteral("Not available"));
                setKernelCell(0, 3, QStringLiteral("Evaluation failed"));
                kernelInventoryStatus->setText(output.isEmpty()
                    ? QStringLiteral("The configured kernel version could not be evaluated.")
                    : output);
                return;
            }

            const bool running = runningKernelRelease == output ||
                runningKernelRelease.startsWith(output + QLatin1Char('-'));
            setKernelCell(0, 1, output);
            setKernelCell(0, 3, running ? QStringLiteral("Running") : QStringLiteral("Next boot"));
            kernelInventoryStatus->setText(running
                ? QStringLiteral("The configured kernel matches the running kernel.")
                : QStringLiteral("The configured kernel differs from the running kernel. Rebuild and switch to activate it."));
        });

        connect(process, &QProcess::errorOccurred, this,
                [this, process](QProcess::ProcessError error) {
            if (error != QProcess::FailedToStart)
                return;
            if (kernelEvaluationProcess == process)
                kernelEvaluationProcess = nullptr;
            setKernelCell(0, 1, QStringLiteral("Not available"));
            setKernelCell(0, 3, QStringLiteral("Evaluation failed"));
            kernelInventoryStatus->setText(
                QStringLiteral("Could not start nix: %1").arg(process->errorString()));
            process->deleteLater();
        });

        process->start(QStringLiteral("nix"), {
            QStringLiteral("eval"),
            QStringLiteral("--raw"),
            QStringLiteral("--no-update-lock-file"),
            flakeDir + QStringLiteral("#nixosConfigurations.nixos.config.boot.kernelPackages.kernel.modDirVersion")
        });
    }

    void startPolkitSession()
    {
        if (polkitSessionProcess && polkitSessionProcess->state() != QProcess::NotRunning)
            return;
        if (!requirePolkitHelper())
            return;

        auto *process = new QProcess(this);
        polkitSessionProcess = process;
        polkitSessionReady = false;
        polkitOutputBuffer.clear();
        process->setProgram(QStringLiteral("/run/wrappers/bin/pkexec"));
        process->setArguments({
            qEnvironmentVariable("KERNEL_MANAGER_POLKIT_HELPER"),
            QStringLiteral("session")
        });
        QProcessEnvironment environment = QProcessEnvironment::systemEnvironment();
        environment.insert(QStringLiteral("SYSTEMD_PAGER"), QStringLiteral("cat"));
        environment.insert(QStringLiteral("SYSTEMD_COLORS"), QStringLiteral("0"));
        process->setProcessEnvironment(environment);
        process->setProcessChannelMode(QProcess::MergedChannels);

        authorizationStatus->setText(
            QStringLiteral("Authenticate once to enable system information and privileged actions."));
        statusBar()->showMessage(QStringLiteral("Waiting for the graphical Polkit authorization dialog…"));

        connect(process, &QProcess::readyReadStandardOutput, this, [this, process]() {
            if (process != polkitSessionProcess)
                return;
            polkitOutputBuffer += QString::fromLocal8Bit(process->readAllStandardOutput());
            qsizetype newline = -1;
            while ((newline = polkitOutputBuffer.indexOf(QLatin1Char('\n'))) >= 0) {
                QString line = polkitOutputBuffer.left(newline);
                polkitOutputBuffer.remove(0, newline + 1);
                if (line.endsWith(QLatin1Char('\r')))
                    line.chop(1);
                handlePolkitSessionLine(line);
            }
        });

        connect(process, &QProcess::finished, this,
                [this, process](int exitCode, QProcess::ExitStatus exitStatus) {
            if (process != polkitSessionProcess) {
                process->deleteLater();
                return;
            }
            polkitSessionProcess = nullptr;
            polkitSessionReady = false;
            privilegedRequestPending = false;
            process->deleteLater();

            if (exitStatus != QProcess::NormalExit || exitCode != 0) {
                authorizationStatus->setText(
                    QStringLiteral("Authorization ended. Press Refresh to authenticate again."));
                statusBar()->showMessage(
                    QStringLiteral("Polkit session ended; privileged actions are unavailable"), 7000);
            } else if (!currentPrivilegedAction.isEmpty()) {
                authorizationStatus->setText(
                    QStringLiteral("The privileged session ended during an operation."));
            }
        });

        connect(process, &QProcess::errorOccurred, this,
                [this, process](QProcess::ProcessError error) {
            if (error != QProcess::FailedToStart)
                return;
            if (process == polkitSessionProcess) {
                polkitSessionProcess = nullptr;
                polkitSessionReady = false;
                privilegedRequestPending = false;
            }
            const QString failure =
                QStringLiteral("Could not start the Polkit session: %1").arg(process->errorString());
            authorizationStatus->setText(failure);
            statusBar()->showMessage(failure, 7000);
            process->deleteLater();
        });

        process->start();
    }

    bool sendPrivilegedRequest(const QString &action)
    {
        if (!polkitSessionReady || !polkitSessionProcess ||
            polkitSessionProcess->state() != QProcess::Running) {
            authorizationStatus->setText(
                QStringLiteral("Authenticate first. Press Refresh to start a Polkit session."));
            return false;
        }
        if (privilegedRequestPending) {
            authorizationStatus->setText(
                QStringLiteral("A system operation is already running. Wait for it to finish."));
            return false;
        }
        const QByteArray request = action.toUtf8() + '\n';
        if (polkitSessionProcess->write(request) != request.size()) {
            authorizationStatus->setText(
                QStringLiteral("Could not send the operation to the privileged session."));
            return false;
        }
        privilegedRequestPending = true;
        return true;
    }

    void handlePolkitSessionLine(const QString &line)
    {
        if (line == QStringLiteral("__KM_SESSION_READY__")) {
            polkitSessionReady = true;
            authorizationStatus->setText(
                QStringLiteral("Administrator authorization active · no more password prompts while this window stays open."));
            statusBar()->showMessage(QStringLiteral("Authorized for this application session"), 5000);
            sendPrivilegedRequest(QStringLiteral("inspect-system"));
            return;
        }

        if (line.startsWith(QStringLiteral("__KM_ACTION_BEGIN__:"))) {
            currentPrivilegedAction = line.mid(QStringLiteral("__KM_ACTION_BEGIN__:").size());
            capturingBootEntries = false;
            capturingGenerations = false;
            if (operationOutput && currentPrivilegedAction != QStringLiteral("inspect-system"))
                operationOutput->clear();
            return;
        }
        if (line == QStringLiteral("__KM_BOOT_BEGIN__")) {
            bootEntriesText.clear();
            capturingBootEntries = true;
            capturingGenerations = false;
            return;
        }
        if (line == QStringLiteral("__KM_BOOT_END__")) {
            capturingBootEntries = false;
            return;
        }
        if (line == QStringLiteral("__KM_GENERATIONS_BEGIN__")) {
            generationsText.clear();
            capturingGenerations = true;
            capturingBootEntries = false;
            return;
        }
        if (line == QStringLiteral("__KM_GENERATIONS_END__")) {
            capturingGenerations = false;
            return;
        }

        if (line.startsWith(QStringLiteral("__KM_ACTION_END__:"))) {
            const QString payload = line.mid(QStringLiteral("__KM_ACTION_END__:").size());
            const QStringList fields = payload.split(QLatin1Char(':'));
            const QString action = fields.value(0);
            bool exitCodeValid = false;
            const int exitCode = fields.value(1).toInt(&exitCodeValid);
            const bool succeeded = exitCodeValid && exitCode == 0;

            if (action == QStringLiteral("inspect-system")) {
                authorizationStatus->setText(succeeded
                    ? QStringLiteral("Administrator authorization active · system information is ready.")
                    : QStringLiteral("Authorized, but system information could not be read. See System info."));
            } else {
                if (operationOutput) {
                    operationOutput->appendPlainText(succeeded
                        ? QStringLiteral("\nOperation completed successfully.")
                        : QStringLiteral("\nOperation failed with exit code %1.").arg(exitCodeValid ? exitCode : -1));
                }
                statusBar()->showMessage(succeeded
                    ? QStringLiteral("Operation completed")
                    : QStringLiteral("Operation failed · see the operation output"), 7000);
                if (succeeded) {
                    refreshState();
                    if (action == QStringLiteral("rebuild-switch"))
                        sendPrivilegedRequest(QStringLiteral("inspect-system"));
                }
            }
            currentPrivilegedAction.clear();
            privilegedRequestPending = false;
            capturingBootEntries = false;
            capturingGenerations = false;
            return;
        }

        if (capturingBootEntries) {
            if (!bootEntriesText.isEmpty())
                bootEntriesText.append(QLatin1Char('\n'));
            bootEntriesText.append(line);
            return;
        }
        if (capturingGenerations) {
            if (!generationsText.isEmpty())
                generationsText.append(QLatin1Char('\n'));
            generationsText.append(line);
            return;
        }
        if (!line.isEmpty() && operationOutput &&
            currentPrivilegedAction != QStringLiteral("inspect-system")) {
            operationOutput->appendPlainText(line);
        } else if (!line.isEmpty() && currentPrivilegedAction == QStringLiteral("inspect-system")) {
            statusBar()->showMessage(line, 5000);
        }
    }

    void runPrivilegedAction(const QString &action, const QString &title)
    {
        if (!polkitSessionReady || !polkitSessionProcess) {
            QMessageBox::warning(
                this, QStringLiteral("Authorization required"),
                QStringLiteral("The Polkit session is not active. Press Refresh and authenticate once."));
            return;
        }
        if (!currentPrivilegedAction.isEmpty()) {
            QMessageBox::information(
                this, QStringLiteral("Operation in progress"),
                QStringLiteral("Wait for the current privileged operation to finish."));
            return;
        }

        auto *dialog = new QDialog(this);
        dialog->setAttribute(Qt::WA_DeleteOnClose);
        dialog->setWindowTitle(title);
        dialog->resize(720, 430);
        auto *layout = new QVBoxLayout(dialog);
        layout->setContentsMargins(14, 12, 14, 12);
        layout->setSpacing(8);

        auto *description = new QLabel(
            QStringLiteral("Using the already-authorized session. No new password prompt is needed."),
            dialog);
        description->setObjectName(QStringLiteral("mutedText"));
        description->setWordWrap(true);
        layout->addWidget(description);

        auto *output = makeOutputPane(dialog);
        output->setMinimumHeight(300);
        output->setPlainText(QStringLiteral("Starting operation…"));
        layout->addWidget(output, 1);

        auto *closeButton = new QPushButton(QStringLiteral("Close"), dialog);
        connect(closeButton, &QPushButton::clicked, dialog, &QDialog::accept);
        auto *buttonRow = new QHBoxLayout();
        buttonRow->addStretch();
        buttonRow->addWidget(closeButton);
        layout->addLayout(buttonRow);

        operationDialog = dialog;
        operationOutput = output;
        dialog->show();

        if (!sendPrivilegedRequest(action)) {
            output->appendPlainText(QStringLiteral("Could not start the operation."));
            return;
        }
        statusBar()->showMessage(title + QStringLiteral(" started"), 5000);
    }

    void showSystemInformation()
    {
        QDialog dialog(this);
        dialog.setWindowTitle(QStringLiteral("System information"));
        dialog.setMinimumSize(720, 560);
        auto *layout = new QVBoxLayout(&dialog);
        layout->setContentsMargins(16, 14, 16, 14);
        layout->setSpacing(9);

        auto *bootLabel = new QLabel(QStringLiteral("Systemd-boot entries"), &dialog);
        bootLabel->setObjectName(QStringLiteral("sectionTitle"));
        layout->addWidget(bootLabel);
        auto *bootPane = makeOutputPane(&dialog);
        bootPane->setMinimumHeight(175);
        bootPane->setPlainText(bootEntriesText);
        layout->addWidget(bootPane, 1);

        auto *generationLabel = new QLabel(QStringLiteral("NixOS system generations"), &dialog);
        generationLabel->setObjectName(QStringLiteral("sectionTitle"));
        layout->addWidget(generationLabel);
        auto *generationPane = makeOutputPane(&dialog);
        generationPane->setMinimumHeight(145);
        generationPane->setPlainText(generationsText);
        layout->addWidget(generationPane, 1);

        auto *closeButton = new QPushButton(QStringLiteral("Close"), &dialog);
        connect(closeButton, &QPushButton::clicked, &dialog, &QDialog::accept);
        auto *buttonRow = new QHBoxLayout();
        buttonRow->addStretch();
        buttonRow->addWidget(closeButton);
        layout->addLayout(buttonRow);
        dialog.exec();
    }

    QString flakeConfigurationText() const
    {
        const QString flake = readFile(flakeDir + QStringLiteral("/flake.nix"));
        if (flake.isEmpty())
            return QStringLiteral("Could not read %1/flake.nix").arg(flakeDir);

        const QStringList lines = flake.split(QLatin1Char('\n'));
        QStringList selected;
        for (qsizetype i = 0; i < lines.size(); ++i) {
            if (lines.at(i).contains(QStringLiteral("boot.kernelPackages")) ||
                lines.at(i).contains(QStringLiteral("rtBoreLtoV3KernelPackagesFor")) ||
                lines.at(i).contains(QStringLiteral("kernelKcfi"))) {
                const qsizetype first = qMax<qsizetype>(0, i - 4);
                const qsizetype last = qMin<qsizetype>(lines.size() - 1, i + 5);
                for (qsizetype n = first; n <= last; ++n) {
                    selected.append(QStringLiteral("%1  %2")
                        .arg(static_cast<qlonglong>(n + 1), 4)
                        .arg(lines.at(n)));
                }
                selected.append(QString());
            }
        }
        return selected.isEmpty()
            ? QStringLiteral("No boot.kernelPackages declaration was found.")
            : selected.join(QLatin1Char('\n'));
    }

    void showFlakeConfiguration()
    {
        QDialog dialog(this);
        dialog.setWindowTitle(QStringLiteral("Kernel Flake configuration"));
        dialog.setMinimumSize(720, 500);
        auto *layout = new QVBoxLayout(&dialog);
        layout->setContentsMargins(16, 14, 16, 14);
        layout->setSpacing(9);

        auto *path = new QLabel(flakeDir, &dialog);
        path->setObjectName(QStringLiteral("mutedText"));
        layout->addWidget(path);

        auto *output = makeOutputPane(&dialog);
        output->setPlainText(flakeConfigurationText());
        layout->addWidget(output, 1);

        auto *closeButton = new QPushButton(QStringLiteral("Close"), &dialog);
        connect(closeButton, &QPushButton::clicked, &dialog, &QDialog::accept);
        auto *buttonRow = new QHBoxLayout();
        buttonRow->addStretch();
        buttonRow->addWidget(closeButton);
        layout->addLayout(buttonRow);
        dialog.exec();
    }

    bool confirmAction(const QString &title, const QString &message)
    {
        QMessageBox dialog(QMessageBox::Warning, title, message,
                           QMessageBox::Yes | QMessageBox::No, this);
        dialog.setDefaultButton(QMessageBox::No);
        dialog.setEscapeButton(dialog.button(QMessageBox::No));
        dialog.setButtonText(QMessageBox::Yes, QStringLiteral("Continue"));
        dialog.setButtonText(QMessageBox::No, QStringLiteral("Cancel"));
        return dialog.exec() == QMessageBox::Yes;
    }

    void openTerminalAction(const QString &title, const QString &command)
    {
        const QString terminalScript =
            QStringLiteral("set +e\n%1\nresult=$?\necho\n"
                           "if [ \"$result\" -eq 0 ]; then "
                           "printf '\\nOperation completed successfully.\\n'; "
                           "else printf '\\nOperation failed with exit code %s.\\n' \"$result\"; fi\n"
                           "read -r -p 'Press Enter to close this window...' _\nexit \"$result\"")
                .arg(command);
        const QStringList arguments{
            QStringLiteral("--title"), title,
            QStringLiteral("-e"), QStringLiteral("bash"),
            QStringLiteral("-lc"), terminalScript
        };
        if (!QProcess::startDetached(QStringLiteral("kitty"), arguments)) {
            QMessageBox::critical(
                this, QStringLiteral("Could not open terminal"),
                QStringLiteral("Kitty could not be started. Check that it is installed and available in PATH."));
            return;
        }
        statusBar()->showMessage(title + QStringLiteral(" opened in Kitty"), 5000);
    }

    bool requirePolkitHelper()
    {
        const QString pkexec = QStringLiteral("/run/wrappers/bin/pkexec");
        if (!QFileInfo(pkexec).isExecutable()) {
            QMessageBox::critical(this, QStringLiteral("Polkit is unavailable"),
                QStringLiteral("The NixOS setuid Polkit wrapper at /run/wrappers/bin/pkexec is missing. Rebuild with security.polkit.enablePkexecWrapper enabled."));
            return false;
        }
        const QString helper = qEnvironmentVariable("KERNEL_MANAGER_POLKIT_HELPER");
        if (helper.isEmpty() || !QFileInfo(helper).isExecutable()) {
            QMessageBox::critical(this, QStringLiteral("Authorization helper unavailable"),
                QStringLiteral("The immutable Polkit helper is missing. Rebuild NixOS before using privileged actions."));
            return false;
        }
        return true;
    }

    bool requireFlakeFiles()
    {
        const bool flakeExists = QFileInfo(flakeDir + QStringLiteral("/flake.nix")).isFile();
        const bool lockExists = QFileInfo(flakeDir + QStringLiteral("/flake.lock")).isFile();
        if (flakeExists && lockExists)
            return true;

        QMessageBox::critical(
            this,
            QStringLiteral("NixOS Flake not found"),
            QStringLiteral("Both flake.nix and flake.lock must exist in:\n%1\n\n"
                           "Set NIXOS_CONFIG_FLAKE to the deployed Flake directory or repair the source tree.")
                .arg(flakeDir));
        return false;
    }

    void updateFlakeInput()
    {
        if (!requireFlakeFiles() || !requirePolkitHelper())
            return;
        if (!confirmAction(
                QStringLiteral("Update CachyOS Flake input?"),
                QStringLiteral("This uses the already-authorized helper session. "
                               "It updates only cachyos-kernel in flake.lock. "
                               "No additional password prompt, kernel build, or system activation is needed.")))
            return;
        runPrivilegedAction(QStringLiteral("update-cachyos"),
                            QStringLiteral("CachyOS Flake input update"));
    }

    void buildKernelOnly()
    {
        if (!requireFlakeFiles())
            return;
        if (!confirmAction(
                QStringLiteral("Build the selected kernel only?"),
                QStringLiteral("This builds the kernel selected by the current Flake. "
                               "A cache miss can take a long time and use substantial CPU and disk space. "
                               "The running kernel and boot entries will not be changed.")))
            return;
        const QString flakeReference = shellQuote(flakeDir + QLatin1Char('#') + kKernelAttribute);
        openTerminalAction(
            QStringLiteral("Kernel-only build"),
            QStringLiteral("nix build --no-link --print-out-paths --show-trace --no-update-lock-file %1")
                .arg(flakeReference));
    }

    void rebuildAndSwitch()
    {
        if (!requireFlakeFiles() || !requirePolkitHelper())
            return;
        if (!confirmAction(
                QStringLiteral("Rebuild and switch the complete NixOS system?"),
                QStringLiteral("This reuses the already-authorized helper session. "
                               "It runs only nixos-rebuild switch for this Flake. "
                               "No additional password prompt is required.")))
            return;
        runPrivilegedAction(QStringLiteral("rebuild-switch"),
                            QStringLiteral("NixOS rebuild and switch"));
    }
};

int main(int argc, char *argv[])
{
    QApplication application(argc, argv);
    QApplication::setApplicationName(kAppName);
    QApplication::setOrganizationName(QStringLiteral("kUmutUK"));
    QApplication::setApplicationDisplayName(kAppName);
    KernelManagerWindow window;
    window.show();
    return application.exec();
}
