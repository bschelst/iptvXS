#include "category_list_viewmodel.h"

CategoryListViewModel::CategoryListViewModel(QObject *parent)
    : QAbstractListModel(parent) {}

void CategoryListViewModel::setRepository(iptvxs::CategoryRepository *repo) {
    repo_ = repo;
    if (serverId_ > 0) loadCategories();
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
    case NameRole: return cat.name;
    case ExternalIdRole: return cat.externalId;
    case TypeRole: return cat.type;
    default: return {};
    }
}

QHash<int, QByteArray> CategoryListViewModel::roleNames() const {
    return {
        {IdRole, "categoryId"},
        {NameRole, "name"},
        {ExternalIdRole, "externalId"},
        {TypeRole, "type"},
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
    return categories_.at(index).name;
}

void CategoryListViewModel::refresh() { loadCategories(); }

void CategoryListViewModel::loadCategories() {
    if (!repo_ || serverId_ <= 0) return;

    beginResetModel();
    categories_ = repo_->findByServer(serverId_, filterType_);
    endResetModel();
    emit countChanged();
}
