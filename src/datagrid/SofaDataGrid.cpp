#include "SofaDataGrid.h"
#include "DataGridEngine.h"
#include "DataGridView.h"
#include <QDebug>
#include <QQmlEngine>

namespace Sofa::DataGrid {
    void DataGridModule::init() {
        qDebug() << "Sofa DataGrid Module Initialized";
        
        qmlRegisterType<DataGridEngine>("sofa.datagrid", 1, 0, "DataGridEngine");
        qmlRegisterType<DataGridView>("sofa.datagrid", 1, 0, "DataGridView");
    }
}
