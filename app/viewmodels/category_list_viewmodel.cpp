// iptvXS Project - Schelstraete Bart - https://iptvxs.schelstraete.org
#include "category_list_viewmodel.h"

#include <algorithm>
#include <QLocale>
#include <QRegularExpression>
#include <QStringList>

namespace {
QString countryNameForCode(QString code) {
    code = code.trimmed().toUpper();
    if (code == QStringLiteral("UK")) {
        return QStringLiteral("United Kingdom");
    }

    const auto country = QLocale::codeToTerritory(code);
    if (country == QLocale::AnyTerritory) {
        return {};
    }
    return QLocale::territoryToString(country);
}

QString compactCountryName(QString countryName) {
    countryName = countryName.trimmed();
    if (countryName.isEmpty()) {
        return countryName;
    }
    if (countryName.size() <= 12) {
        return countryName;
    }

    const auto parts = countryName.split(QRegularExpression(QStringLiteral("[\\s\\-]+")),
                                         Qt::SkipEmptyParts);
    QString compact;
    for (const auto &part : parts) {
        const auto trimmed = part.trimmed();
        if (trimmed.isEmpty()) continue;
        const auto lower = trimmed.toLower();
        if (lower == QStringLiteral("and") || lower == QStringLiteral("of") ||
            lower == QStringLiteral("the")) {
            continue;
        }
        compact.append(trimmed.left(1).toUpper());
    }

    if (compact.size() >= 2) {
        return compact;
    }

    return countryName.left(12).trimmed() + QStringLiteral("…");
}
} // namespace

QString CategoryListViewModel::displayNameFor(const QString &name) {
    const auto parts = name.split(';', Qt::KeepEmptyParts);
    if (parts.size() <= 1) {
        return name.trimmed();
    }

    QStringList cleaned;
    cleaned.reserve(parts.size());
    for (const auto &part : parts) {
        const auto trimmed = part.trimmed();
            if (!trimmed.isEmpty()) {
                if (cleaned.isEmpty() && trimmed.size() == 2 && trimmed == trimmed.toUpper()) {
                    const auto countryName = countryNameForCode(trimmed);
                    if (!countryName.isEmpty()) {
                        cleaned.append(compactCountryName(countryName));
                        continue;
                    }
                }
                cleaned.append(trimmed);
        }
    }
    if (cleaned.isEmpty()) {
        return name.trimmed();
    }
    return cleaned.join(QStringLiteral(" / "));
}

CategoryListViewModel::CategoryListViewModel(QObject *parent)
    : QAbstractListModel(parent) {}

void CategoryListViewModel::setRepository(iptvxs::CategoryRepository *repo) {
    repo_ = repo;
    if (serverId_ > 0) loadCategories();
}

void CategoryListViewModel::setCategorySettingsRepository(iptvxs::CategorySettingsRepository *repo) {
    settingsRepo_ = repo;
    if (settingsRepo_) {
        connect(settingsRepo_, &iptvxs::CategorySettingsRepository::settingsChanged,
                this, &CategoryListViewModel::refresh);
    }
}

int CategoryListViewModel::rowCount(const QModelIndex &parent) const {
    if (parent.isValid()) return 0;
    return static_cast<int>(categories_.size());
}

QVariant CategoryListViewModel::data(const QModelIndex &index, int role) const {
    if (!index.isValid() || index.row() >= categories_.size()) return {};

    const auto &cat = categories_.at(index.row());
    switch (role) {
    case IdRole: return QVariant::fromValue(cat.id);
    case NameRole: {
        if (settingsRepo_) {
            auto custom = settingsRepo_->customName(cat.id);
            if (!custom.isEmpty()) return custom;
        }
        return displayNameFor(cat.name);
    }
    case ExternalIdRole: return cat.externalId;
    case TypeRole: return cat.type;
    case HiddenRole: return settingsRepo_ ? settingsRepo_->isHidden(cat.id) : false;
    case FavoriteRole: return settingsRepo_ ? settingsRepo_->isFavorite(cat.id) : false;
    case CustomNameRole: return settingsRepo_ ? settingsRepo_->customName(cat.id) : QString();
    default: return {};
    }
}

QHash<int, QByteArray> CategoryListViewModel::roleNames() const {
    return {
        {IdRole, "categoryId"},
        {NameRole, "name"},
        {ExternalIdRole, "externalId"},
        {TypeRole, "type"},
        {HiddenRole, "hidden"},
        {FavoriteRole, "favorite"},
        {CustomNameRole, "customName"},
    };
}

int64_t CategoryListViewModel::serverId() const { return serverId_; }

void CategoryListViewModel::setServerId(int64_t id) {
    if (serverId_ != id) {
        serverId_ = id;
        emit serverIdChanged();
        loadCategories();
    }
}

QString CategoryListViewModel::filterType() const { return filterType_; }

void CategoryListViewModel::setFilterType(const QString &type) {
    if (filterType_ != type) {
        filterType_ = type;
        emit filterTypeChanged();
        loadCategories();
    }
}

int CategoryListViewModel::count() const {
    return static_cast<int>(categories_.size());
}

int64_t CategoryListViewModel::categoryIdAt(int index) const {
    if (index < 0 || index >= categories_.size()) return 0;
    return categories_.at(index).id;
}

QString CategoryListViewModel::categoryNameAt(int index) const {
    if (index < 0 || index >= categories_.size()) return {};
    if (settingsRepo_) {
        auto custom = settingsRepo_->customName(categories_.at(index).id);
        if (!custom.isEmpty()) return custom;
    }
    return displayNameFor(categories_.at(index).name);
}

void CategoryListViewModel::refresh() { loadCategories(); }

void CategoryListViewModel::setBrowseContext(int64_t serverId, const QString &type) {
    bool serverChanged = serverId_ != serverId;
    bool typeChanged = filterType_ != type;
    if (!serverChanged && !typeChanged) {
        return;
    }

    serverId_ = serverId;
    filterType_ = type;

    if (serverChanged) emit serverIdChanged();
    if (typeChanged) emit filterTypeChanged();

    loadCategories();
}

void CategoryListViewModel::toggleHidden(int64_t categoryId) {
    if (!settingsRepo_) return;
    settingsRepo_->setHidden(categoryId, !settingsRepo_->isHidden(categoryId));
}

void CategoryListViewModel::toggleFavorite(int64_t categoryId) {
    if (!settingsRepo_) return;
    settingsRepo_->setFavorite(categoryId, !settingsRepo_->isFavorite(categoryId));
}

void CategoryListViewModel::renameCategory(int64_t categoryId, const QString &name) {
    if (!settingsRepo_) return;
    settingsRepo_->setCustomName(categoryId, name);
    loadCategories();
}

bool CategoryListViewModel::isCategoryHidden(int64_t categoryId) const {
    if (!settingsRepo_) return false;
    return settingsRepo_->isHidden(categoryId);
}

bool CategoryListViewModel::isCategoryFavorite(int64_t categoryId) const {
    if (!settingsRepo_) return false;
    return settingsRepo_->isFavorite(categoryId);
}

void CategoryListViewModel::loadCategories() {
    if (!repo_ || serverId_ <= 0) return;

    beginResetModel();
    categories_ = repo_->findByServer(serverId_, filterType_);

    // Sort favorites to the top while preserving alphabetical order within groups
    if (settingsRepo_) {
        auto favIds = settingsRepo_->favoriteCategoryIds();
        if (!favIds.isEmpty()) {
            std::stable_sort(categories_.begin(), categories_.end(),
                             [&favIds](const iptvxs::Category &a, const iptvxs::Category &b) {
                                 bool aFav = favIds.contains(a.id);
                                 bool bFav = favIds.contains(b.id);
                                 if (aFav != bFav) return aFav;
                                 return false; // preserve existing order within same group
                             });
        }
    }

    endResetModel();
    emit countChanged();
}
