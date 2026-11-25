#include <QApplication>
#include <QAbstractItemView>
#include <QHeaderView>
#include <QList>
#include <QDir>
#include <QFile>
#include <QFileInfo>
#include <QFrame>
#include <QGridLayout>
#include <QHBoxLayout>
#include <QJsonArray>
#include <QJsonDocument>
#include <QJsonObject>
#include <QLabel>
#include <QMainWindow>
#include <QMessageBox>
#include <QPlainTextEdit>
#include <QProcess>
#include <QProcessEnvironment>
#include <QPushButton>
#include <QStringList>
#include <QScrollArea>
#include <QStackedWidget>
#include <QStatusBar>
#include <QTableWidget>
#include <QTableWidgetItem>
#include <QVBoxLayout>
#include <QWidget>

#include <functional>

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

QFrame *makeCard(const QString &title, const QString &value, const QString &description,
                 QWidget *parent = nullptr)
{
    auto *card = new QFrame(parent);
    card->setObjectName(QStringLiteral("metricCard"));
    auto *layout = new QVBoxLayout(card);
    layout->setContentsMargins(19, 17, 19, 18);
    layout->setSpacing(8);

    auto *heading = new QLabel(title, card);
    heading->setObjectName(QStringLiteral("cardHeading"));
    auto *mainValue = new QLabel(value, card);
    mainValue->setObjectName(QStringLiteral("metricValue"));
    mainValue->setWordWrap(true);
    auto *detail = new QLabel(description, card);
    detail->setObjectName(QStringLiteral("mutedText"));
    detail->setWordWrap(true);

    layout->addWidget(heading);
    layout->addWidget(mainValue);
    layout->addWidget(detail);
    layout->addStretch();
    return card;
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
    {
        setWindowTitle(kAppName);
        setMinimumSize(940, 650);
        resize(1180, 760);
        setStyleSheet(styleSheetText());

        buildWindow();
        refreshState();
        statusBar()->showMessage(QStringLiteral("Read-only inspection · NixOS declarative kernel management"));
    }

private:
    QString flakeDir = flakeDirectory();

    QStackedWidget *pages = nullptr;
    QLabel *pageTitle = nullptr;
    QLabel *runningKernelValue = nullptr;
    QLabel *profileValue = nullptr;
    QLabel *revisionValue = nullptr;
    QLabel *systemValue = nullptr;
    QLabel *overviewFlakeValue = nullptr;
    QLabel *bootStatus = nullptr;
    QPlainTextEdit *bootOutput = nullptr;
    QPlainTextEdit *generationOutput = nullptr;
    QPlainTextEdit *flakeOutput = nullptr;
    QTableWidget *kernelTable = nullptr;
    QTableWidget *bootTable = nullptr;
    QLabel *kernelInventoryStatus = nullptr;
    QList<QPushButton *> navigationButtons;

    static QString styleSheetText()
    {
        return QStringLiteral(R"(
            QWidget {
                background: #11141b;
                color: #edf0f7;
                font-family: "Inter", "Noto Sans", sans-serif;
                font-size: 13px;
            }
            QFrame#sidebar {
                background: #171b24;
                border-right: 1px solid #29303c;
            }
            QLabel#brandMark {
                background: #69aee8;
                color: #20232c;
                border-radius: 13px;
                font-size: 21px;
                font-weight: 800;
                padding: 7px;
            }
            QLabel#brandTitle {
                font-size: 15px;
                font-weight: 700;
            }
            QLabel#brandSubtitle, QLabel#mutedText, QLabel#pageSubtitle {
                color: #9ca7b8;
            }
            QLabel#eyebrow {
                color: #69aee8;
                font-size: 11px;
                font-weight: 700;
                letter-spacing: 1px;
            }
            QLabel#pageTitle {
                font-size: 25px;
                font-weight: 750;
            }
            QLabel#heroValue {
                font-size: 27px;
                font-weight: 750;
                color: #ffffff;
            }
            QLabel#metricValue {
                font-size: 19px;
                font-weight: 700;
                color: #f5f6fa;
            }
            QLabel#cardHeading {
                color: #b9c2d0;
                font-size: 12px;
                font-weight: 650;
            }
            QLabel#statusPill {
                background: #1d3b34;
                color: #9be2c4;
                border: 1px solid #2c6856;
                border-radius: 10px;
                padding: 6px 11px;
                font-size: 11px;
                font-weight: 750;
            }
            QFrame#heroCard, QFrame#metricCard, QFrame#actionCard, QFrame#sectionCard {
                background: #1a202b;
                border: 1px solid #2c3543;
                border-radius: 15px;
            }
            QFrame#heroCard {
                background: #202631;
                border: 1px solid #3a3541;
            }
            QPushButton#navButton {
                background: transparent;
                color: #aeb8c8;
                border: none;
                border-radius: 9px;
                text-align: left;
                padding: 12px 14px;
                font-size: 13px;
                font-weight: 600;
            }
            QPushButton#navButton:hover {
                background: #242b37;
                color: #ffffff;
            }
            QPushButton#navButton:checked {
                background: #20364a;
                color: #c2e2ff;
                border-left: 3px solid #69aee8;
                padding-left: 11px;
            }
            QPushButton#primaryButton {
                background: #69aee8;
                color: #25232b;
                border: none;
                border-radius: 9px;
                padding: 10px 15px;
                font-weight: 750;
            }
            QPushButton#primaryButton:hover {
                background: #8bc7fa;
            }
            QPushButton#secondaryButton {
                background: #293241;
                color: #e5eaf3;
                border: 1px solid #3a4658;
                border-radius: 9px;
                padding: 9px 14px;
                font-weight: 650;
            }
            QPushButton#secondaryButton:hover {
                background: #354153;
            }
            QPlainTextEdit#outputPane {
                background: #10141c;
                color: #cbd5e1;
                border: 1px solid #303948;
                border-radius: 11px;
                padding: 12px;
                selection-background-color: #285b82;
                font-family: "JetBrains Mono", "DejaVu Sans Mono", monospace;
                font-size: 12px;
            }
            QTableWidget#kernelTable, QTableWidget#bootTable {
                background: #171c23;
                alternate-background-color: #202832;
                color: #edf0f7;
                border: 1px solid #37414d;
                border-radius: 8px;
                gridline-color: transparent;
                selection-background-color: #24537b;
                selection-color: #ffffff;
            }
            QTableWidget#kernelTable::item, QTableWidget#bootTable::item {
                padding: 9px 10px;
                border-bottom: 1px solid #303944;
            }
            QHeaderView::section {
                background: #222a33;
                color: #c8d3df;
                padding: 9px 10px;
                border: none;
                border-bottom: 1px solid #3a4654;
                font-weight: 700;
            }
            QTableCornerButton::section {
                background: #222a33;
                border: none;
            }
            QStatusBar {
                background: #171b24;
                color: #aab4c4;
                border-top: 1px solid #29303c;
            }
            QScrollArea, QScrollArea > QWidget > QWidget {
                background: transparent;
                border: none;
            }
        )");
    }

    void buildWindow()
    {
        auto *central = new QWidget(this);
        auto *root = new QHBoxLayout(central);
        root->setContentsMargins(0, 0, 0, 0);
        root->setSpacing(0);

        auto *sidebar = new QFrame(central);
        sidebar->setObjectName(QStringLiteral("sidebar"));
        sidebar->setFixedWidth(226);
        auto *sideLayout = new QVBoxLayout(sidebar);
        sideLayout->setContentsMargins(18, 24, 18, 20);
        sideLayout->setSpacing(12);

        auto *brandRow = new QHBoxLayout();
        auto *mark = new QLabel(QStringLiteral("K"), sidebar);
        mark->setObjectName(QStringLiteral("brandMark"));
        mark->setAlignment(Qt::AlignCenter);
        mark->setFixedSize(42, 42);
        auto *brandText = new QVBoxLayout();
        auto *brand = new QLabel(QStringLiteral("Kernel Manager"), sidebar);
        brand->setObjectName(QStringLiteral("brandTitle"));
        auto *brandSubtitle = new QLabel(QStringLiteral("NixOS · CachyOS"), sidebar);
        brandSubtitle->setObjectName(QStringLiteral("brandSubtitle"));
        brandText->addWidget(brand);
        brandText->addWidget(brandSubtitle);
        brandRow->addWidget(mark);
        brandRow->addLayout(brandText);
        brandRow->addStretch();
        sideLayout->addLayout(brandRow);
        sideLayout->addSpacing(24);

        auto *navLabel = new QLabel(QStringLiteral("WORKSPACE"), sidebar);
        navLabel->setObjectName(QStringLiteral("eyebrow"));
        sideLayout->addWidget(navLabel);

        pages = new QStackedWidget(central);
        addNavigation(sideLayout, QStringLiteral("Kernel catalogue"), 0);
        addNavigation(sideLayout, QStringLiteral("Boot entries"), 1);
        addNavigation(sideLayout, QStringLiteral("Kernel configuration"), 2);
        addNavigation(sideLayout, QStringLiteral("Kernel actions"), 3);
        sideLayout->addStretch();

        auto *sideNote = new QLabel(
            QStringLiteral("Declarative kernel management\nNo direct bootloader edits"),
            sidebar);
        sideNote->setObjectName(QStringLiteral("brandSubtitle"));
        sideNote->setWordWrap(true);
        sideLayout->addWidget(sideNote);

        auto *content = new QWidget(central);
        auto *contentLayout = new QVBoxLayout(content);
        contentLayout->setContentsMargins(30, 25, 30, 18);
        contentLayout->setSpacing(18);

        auto *header = new QHBoxLayout();
        auto *headingColumn = new QVBoxLayout();
        pageTitle = new QLabel(QStringLiteral("Kernel catalogue"), content);
        pageTitle->setObjectName(QStringLiteral("pageTitle"));
        auto *subtitle = new QLabel(
            QStringLiteral("Review the active CachyOS kernel, boot entries and declarative Flake selection."),
            content);
        subtitle->setObjectName(QStringLiteral("pageSubtitle"));
        headingColumn->addWidget(pageTitle);
        headingColumn->addWidget(subtitle);
        header->addLayout(headingColumn);
        header->addStretch();
        auto *refreshButton = new QPushButton(QStringLiteral("Refresh status"), content);
        refreshButton->setObjectName(QStringLiteral("secondaryButton"));
        connect(refreshButton, &QPushButton::clicked, this, [this]() { refreshState(); });
        header->addWidget(refreshButton, 0, Qt::AlignVCenter);
        contentLayout->addLayout(header);

        pages->addWidget(createOverviewPage());
        pages->addWidget(createBootPage());
        pages->addWidget(createFlakePage());
        pages->addWidget(createActionsPage());
        contentLayout->addWidget(pages, 1);

        root->addWidget(sidebar);
        root->addWidget(content, 1);
        setCentralWidget(central);
        setStatusBar(new QStatusBar(this));
        if (!navigationButtons.isEmpty())
            navigationButtons.first()->setChecked(true);
    }

    void addNavigation(QVBoxLayout *layout, const QString &label, int pageIndex)
    {
        auto *button = new QPushButton(label, this);
        button->setObjectName(QStringLiteral("navButton"));
        button->setCheckable(true);
        button->setCursor(Qt::PointingHandCursor);
        navigationButtons.append(button);
        layout->addWidget(button);
        connect(button, &QPushButton::clicked, this, [this, pageIndex, button, label]() {
            for (auto *nav : navigationButtons)
                nav->setChecked(nav == button);
            pages->setCurrentIndex(pageIndex);
            pageTitle->setText(label);
            if (pageIndex == 1)
                refreshBootInformation();
            if (pageIndex == 2)
                refreshFlakeInformation();
        });
    }

    QWidget *createOverviewPage()
    {
        auto *page = new QWidget(this);
        auto *layout = new QVBoxLayout(page);
        layout->setContentsMargins(0, 0, 0, 0);
        layout->setSpacing(17);

        auto *hero = new QFrame(page);
        hero->setObjectName(QStringLiteral("heroCard"));
        auto *heroLayout = new QHBoxLayout(hero);
        heroLayout->setContentsMargins(23, 20, 23, 21);
        auto *heroText = new QVBoxLayout();
        auto *eyebrow = new QLabel(QStringLiteral("CURRENTLY RUNNING"), hero);
        eyebrow->setObjectName(QStringLiteral("eyebrow"));
        runningKernelValue = new QLabel(QStringLiteral("Detecting kernel…"), hero);
        runningKernelValue->setObjectName(QStringLiteral("heroValue"));
        auto *heroDescription = new QLabel(
            QStringLiteral("This is the kernel currently booted by the running system."),
            hero);
        heroDescription->setObjectName(QStringLiteral("mutedText"));
        heroText->addWidget(eyebrow);
        heroText->addWidget(runningKernelValue);
        heroText->addWidget(heroDescription);
        heroLayout->addLayout(heroText);
        heroLayout->addStretch();
        auto *runningPill = new QLabel(QStringLiteral("●  RUNNING"), hero);
        runningPill->setObjectName(QStringLiteral("statusPill"));
        heroLayout->addWidget(runningPill, 0, Qt::AlignTop);
        layout->addWidget(hero);

        auto *grid = new QGridLayout();
        grid->setHorizontalSpacing(13);
        grid->setVerticalSpacing(13);
        auto *profileCard = makeCard(
            QStringLiteral("CONFIGURED KERNEL"),
            QStringLiteral("Loading…"),
            QStringLiteral("Kernel expression from the NixOS Flake."),
            page);
        profileValue = profileCard->findChild<QLabel *>(QStringLiteral("metricValue"));
        auto *revisionCard = makeCard(
            QStringLiteral("CACHYOS SOURCE REVISION"),
            QStringLiteral("Loading…"),
            QStringLiteral("Locked cachyos-kernel input in flake.lock."),
            page);
        revisionValue = revisionCard->findChild<QLabel *>(QStringLiteral("metricValue"));
        auto *systemCard = makeCard(
            QStringLiteral("ACTIVE SYSTEM GENERATION"),
            QStringLiteral("Loading…"),
            QStringLiteral("Resolved /run/current-system target."),
            page);
        systemValue = systemCard->findChild<QLabel *>(QStringLiteral("metricValue"));
        auto *flakeCard = makeCard(
            QStringLiteral("FLAKE DIRECTORY"),
            flakeDir,
            QStringLiteral("Source used by kernel-manager actions."),
            page);
        overviewFlakeValue = flakeCard->findChild<QLabel *>(QStringLiteral("metricValue"));
        grid->addWidget(profileCard, 0, 0);
        grid->addWidget(revisionCard, 0, 1);
        grid->addWidget(systemCard, 1, 0);
        grid->addWidget(flakeCard, 1, 1);
        layout->addLayout(grid);

        auto *tip = new QFrame(page);
        tip->setObjectName(QStringLiteral("sectionCard"));
        auto *tipLayout = new QVBoxLayout(tip);
        tipLayout->setContentsMargins(18, 15, 18, 16);
        auto *tipTitle = new QLabel(QStringLiteral("Safe by design"), tip);
        tipTitle->setObjectName(QStringLiteral("cardHeading"));
        auto *tipText = new QLabel(
            QStringLiteral("Inspection is read-only. Updating the CachyOS lock input, building the kernel, "
                           "and switching the complete NixOS system are separate actions with their own "
                           "confirmation prompts."),
            tip);
        tipText->setObjectName(QStringLiteral("mutedText"));
        tipText->setWordWrap(true);
        tipLayout->addWidget(tipTitle);
        tipLayout->addWidget(tipText);
        layout->addWidget(tip);
        layout->addStretch();
        return wrapInScrollArea(page);
    }

    QWidget *createBootPage()
    {
        auto *page = new QWidget(this);
        auto *layout = new QVBoxLayout(page);
        layout->setContentsMargins(0, 0, 0, 0);
        layout->setSpacing(12);

        auto *description = new QLabel(
            QStringLiteral("Read-only view of systemd-boot entries and NixOS system generations."),
            page);
        description->setObjectName(QStringLiteral("mutedText"));
        layout->addWidget(description);

        auto *bootTitle = new QLabel(QStringLiteral("SYSTEMD-BOOT ENTRIES"), page);
        bootTitle->setObjectName(QStringLiteral("eyebrow"));
        bootOutput = makeOutputPane(page);
        bootOutput->setMinimumHeight(205);
        bootStatus = new QLabel(QStringLiteral("Refresh to inspect the boot entries."), page);
        bootStatus->setObjectName(QStringLiteral("mutedText"));
        auto *generationTitle = new QLabel(QStringLiteral("NIXOS SYSTEM GENERATIONS"), page);
        generationTitle->setObjectName(QStringLiteral("eyebrow"));
        generationOutput = makeOutputPane(page);
        generationOutput->setMinimumHeight(155);
        layout->addWidget(bootTitle);
        layout->addWidget(bootOutput, 2);
        layout->addWidget(bootStatus);
        layout->addWidget(generationTitle);
        layout->addWidget(generationOutput, 1);
        return wrapInScrollArea(page);
    }

    QWidget *createFlakePage()
    {
        auto *page = new QWidget(this);
        auto *layout = new QVBoxLayout(page);
        layout->setContentsMargins(0, 0, 0, 0);
        layout->setSpacing(12);
        auto *description = new QLabel(
            QStringLiteral("The selected kernel stays declarative in nixos/flake.nix. "
                           "This page only displays the current declaration."),
            page);
        description->setObjectName(QStringLiteral("mutedText"));
        auto *path = new QLabel(flakeDir + QStringLiteral("/flake.nix"), page);
        path->setObjectName(QStringLiteral("eyebrow"));
        flakeOutput = makeOutputPane(page);
        layout->addWidget(description);
        layout->addWidget(path);
        layout->addWidget(flakeOutput, 1);
        return wrapInScrollArea(page);
    }

    QWidget *createActionsPage()
    {
        auto *page = new QWidget(this);
        auto *layout = new QVBoxLayout(page);
        layout->setContentsMargins(0, 0, 0, 0);
        layout->setSpacing(14);

        auto *description = new QLabel(
            QStringLiteral("Each operation opens a Kitty terminal so sudo can request your password "
                           "and the full Nix output remains visible."),
            page);
        description->setObjectName(QStringLiteral("mutedText"));
        description->setWordWrap(true);
        layout->addWidget(description);
        layout->addWidget(makeActionCard(
            QStringLiteral("Update CachyOS Flake input"),
            QStringLiteral("Updates only the cachyos-kernel entry in flake.lock. "
                           "It does not build or activate a kernel."),
            QStringLiteral("Update lock input"),
            [this]() { updateFlakeInput(); },
            page));
        layout->addWidget(makeActionCard(
            QStringLiteral("Build selected kernel only"),
            QStringLiteral("Builds the kernel selected by this Flake. "
                           "A cache miss may require a long local build; no system switch occurs."),
            QStringLiteral("Build kernel"),
            [this]() { buildKernelOnly(); },
            page));
        layout->addWidget(makeActionCard(
            QStringLiteral("Rebuild and switch NixOS"),
            QStringLiteral("Runs nixos-rebuild switch for the complete current Flake. "
                           "This activates a new system generation and does not update flake.lock."),
            QStringLiteral("Rebuild and switch"),
            [this]() { rebuildAndSwitch(); },
            page,
            true));
        layout->addStretch();
        return wrapInScrollArea(page);
    }

    QWidget *wrapInScrollArea(QWidget *page)
    {
        auto *scroll = new QScrollArea(this);
        scroll->setWidgetResizable(true);
        scroll->setFrameShape(QFrame::NoFrame);
        scroll->setWidget(page);
        return scroll;
    }

    QWidget *makeActionCard(const QString &title, const QString &description,
                            const QString &buttonText, const std::function<void()> &callback,
                            QWidget *parent, bool destructive = false)
    {
        auto *card = new QFrame(parent);
        card->setObjectName(QStringLiteral("actionCard"));
        auto *row = new QHBoxLayout(card);
        row->setContentsMargins(19, 17, 19, 17);
        row->setSpacing(18);
        auto *textColumn = new QVBoxLayout();
        auto *heading = new QLabel(title, card);
        heading->setObjectName(QStringLiteral("metricValue"));
        auto *detail = new QLabel(description, card);
        detail->setObjectName(QStringLiteral("mutedText"));
        detail->setWordWrap(true);
        textColumn->addWidget(heading);
        textColumn->addWidget(detail);
        row->addLayout(textColumn, 1);
        auto *button = new QPushButton(buttonText, card);
        button->setObjectName(destructive ? QStringLiteral("secondaryButton")
                                          : QStringLiteral("primaryButton"));
        button->setMinimumWidth(150);
        connect(button, &QPushButton::clicked, this, callback);
        row->addWidget(button, 0, Qt::AlignVCenter);
        return card;
    }

    void refreshState()
    {
        const QString flake = readFile(flakeDir + QStringLiteral("/flake.nix"));
        const QString lock = readFile(flakeDir + QStringLiteral("/flake.lock"));
        if (runningKernelValue)
            runningKernelValue->setText(runReadOnly(QStringLiteral("uname"), {QStringLiteral("-r")}, 2500));
        if (profileValue) {
            const bool knownProfile =
                flake.contains(QStringLiteral("rtBoreLtoV3KernelPackagesFor config.kumutuk.host.kernelKcfi"));
            profileValue->setText(knownProfile
                ? QStringLiteral("CachyOS RT-Bore-LTO")
                : (flake.isEmpty() ? QStringLiteral("Flake unavailable")
                                   : QStringLiteral("Custom Flake expression")));
        }
        if (revisionValue) {
            QString revision = QStringLiteral("unknown");
            const QJsonDocument document = QJsonDocument::fromJson(lock.toUtf8());
            if (document.isObject()) {
                const QJsonObject nodes = document.object().value(QStringLiteral("nodes")).toObject();
                const QJsonObject kernel = nodes.value(QStringLiteral("cachyos-kernel")).toObject();
                revision = kernel.value(QStringLiteral("locked")).toObject()
                               .value(QStringLiteral("rev")).toString(QStringLiteral("unknown"));
            }
            revisionValue->setText(revision.left(12));
            revisionValue->setToolTip(revision);
        }
        if (systemValue) {
            const QString target = QFileInfo(QStringLiteral("/run/current-system")).canonicalFilePath();
            systemValue->setText(target.isEmpty() ? QStringLiteral("Not available") : target);
        }
        if (overviewFlakeValue)
            overviewFlakeValue->setText(flakeDir);

        refreshBootInformation();
        refreshFlakeInformation();
        statusBar()->showMessage(
            flake.isEmpty() || lock.isEmpty()
                ? QStringLiteral("Flake files are missing or unreadable · check the configured directory")
                : QStringLiteral("Status refreshed · inspection did not change the system"),
            6000);
    }

    void refreshBootInformation()
    {
        if (!bootOutput || !generationOutput)
            return;
        const QString boot = runReadOnly(
            QStringLiteral("bootctl"), {QStringLiteral("list"), QStringLiteral("--no-pager")});
        const QString generations = runReadOnly(
            QStringLiteral("nix-env"),
            {QStringLiteral("--profile"), QStringLiteral("/nix/var/nix/profiles/system"),
             QStringLiteral("--list-generations")});
        bootOutput->setPlainText(boot);
        generationOutput->setPlainText(generations);
        if (bootStatus)
            bootStatus->setText(QStringLiteral("Read-only bootloader inspection · no entry was changed"));
    }

    void refreshFlakeInformation()
    {
        if (!flakeOutput)
            return;
        const QString flake = readFile(flakeDir + QStringLiteral("/flake.nix"));
        if (flake.isEmpty()) {
            flakeOutput->setPlainText(QStringLiteral("Could not read %1/flake.nix").arg(flakeDir));
            return;
        }

        const QStringList lines = flake.split(QLatin1Char('\n'));
        QStringList selected;
        for (qsizetype i = 0; i < lines.size(); ++i) {
            if (lines.at(i).contains(QStringLiteral("boot.kernelPackages")) ||
                lines.at(i).contains(QStringLiteral("rtBoreLtoV3KernelPackagesFor")) ||
                lines.at(i).contains(QStringLiteral("kernelKcfi"))) {
                const qsizetype first = qMax<qsizetype>(0, i - 4);
                const qsizetype last = qMin<qsizetype>(lines.size() - 1, i + 5);
                for (qsizetype n = first; n <= last; ++n)
                    selected.append(QStringLiteral("%1  %2")
                                        .arg(static_cast<qlonglong>(n + 1), 4)
                                        .arg(lines.at(n)));
                selected.append(QString());
            }
        }
        flakeOutput->setPlainText(selected.isEmpty()
            ? QStringLiteral("No boot.kernelPackages declaration was found.")
            : selected.join(QLatin1Char('\n')));
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

    bool requireFlakeFiles()
    {
        const bool flakeExists = QFileInfo(flakeDir + QStringLiteral("/flake.nix")).isFile();
        const bool lockExists = QFileInfo(flakeDir + QStringLiteral("/flake.lock")).isFile();
        if (flakeExists && lockExists)
            return true;

        QMessageBox::critical(
            this,
            QStringLiteral("NixOS Flake not found"),
            QStringLiteral("Both flake.nix and flake.lock must exist in:\\n%1\\n\\n"
                           "Set NIXOS_CONFIG_FLAKE to the deployed Flake directory or repair the source tree.")
                .arg(flakeDir));
        return false;
    }

    void updateFlakeInput()
    {
        if (!requireFlakeFiles())
            return;
        if (!confirmAction(
                QStringLiteral("Update CachyOS Flake input?"),
                QStringLiteral("Only cachyos-kernel in flake.lock will be updated. "
                               "No kernel build or system activation will be started. "
                               "Review the resulting lock diff before choosing another action.")))
            return;
        openTerminalAction(
            QStringLiteral("CachyOS Flake input update"),
            QStringLiteral("sudo nix flake update --flake %1 cachyos-kernel").arg(shellQuote(flakeDir)));
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
        if (!requireFlakeFiles())
            return;
        if (!confirmAction(
                QStringLiteral("Rebuild and switch the complete NixOS system?"),
                QStringLiteral("This runs sudo nixos-rebuild switch for the current Flake and activates "
                               "a new system generation. It does not update flake.lock. "
                               "Continue only after reviewing the configuration and its build requirements.")))
            return;
        const QString flakeReference = shellQuote(flakeDir + QStringLiteral("#nixos"));
        openTerminalAction(
            QStringLiteral("NixOS rebuild and switch"),
            QStringLiteral("sudo nixos-rebuild switch --flake %1").arg(flakeReference));
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
