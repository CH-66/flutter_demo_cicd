# 功能开发计划：历史账单编辑与删除

- **功能ID**: `feature-002`
- **功能名称**: 历史账单编辑与删除
- **状态**: 规划中
- **负责人**: AI助手
- **依赖功能**: `feature-001` (账单分类管理) - 编辑功能需要分类选择器。

---

## 1. 目标 (Goals)

为用户提供管理其历史交易记录的基本能力，从而：
-   **提升数据准确性**: 用户可以随时修正被错误解析或需要补充信息的交易记录（如修改金额、商家，添加备注）。
-   **增强数据可控性**: 用户可以删除重复的、错误的或不再需要的交易记录。
-   **完善核心闭环**: 补全记账流程中"增、删、改、查"这一基本CRUD闭环，是应用走向成熟的关键一步。

## 2. 功能规格 (Functional Specification)

### 2.1 用户故事

-   **作为一名用户**，当我发现一条自动记账的商家名称不准确时，我希望能方便地**修改**它。
-   **作为一名用户**，如果我忘记给一笔支出选择分类，我希望能后续在历史记录里为它**补上分类**。
-   **作为一名用户**，如果因为重复收到通知导致了重复记账，我希望能**删除**掉多余的那条记录。
-   **作为一名用户**，在删除一条记录时，我希望能有**二次确认**，以防手滑误删。

### 2.2 核心功能点

1.  **删除功能**:
    -   在"历史账单"页面的每一条记录上，提供一个明确的"删除"入口。
    -   点击删除后，必须弹出一个`AlertDialog`进行二次确认。
    -   用户确认后，该条记录从数据库和UI上被移除。
2.  **编辑功能**:
    -   在"历史账单"页面的每一条记录上，提供一个明确的"编辑"入口。
    -   点击编辑后，跳转到一个独立的"编辑账单"页面。
    -   "编辑账单"页面应预先填入该条记录的所有现有信息（金额、商家、类型、分类、日期、备注等）。
    -   用户可以在此页面修改所有可编辑字段。
    -   点击"保存"后，更新数据库中的记录，并返回到历史账单页面，UI上应显示更新后的信息。

## 3. 技术实现方案 (Technical Implementation Plan)

### 3.1 数据模型层 (Data Model)
-   无需变更。现有的 `Transaction` 模型已包含所有需要编辑的字段。

### 3.2 数据库层 (Service & Database)
-   在 `TransactionService` 中新增核心方法:
    -   `Future<void> updateTransaction(Transaction transaction)`:
        -   内部执行 `db.update('transactions', transaction.toMap(), where: 'id = ?', whereArgs: [transaction.id])`。
    -   `Future<void> deleteTransaction(int id)`:
        -   内部执行 `db.delete('transactions', where: 'id = ?', whereArgs: [id])`。

### 3.3 UI/UX 层

1.  **历史账单页面 (`lib/presentation/screens/history_screen.dart`)**
    -   **交互设计**: 为避免UI混乱，推荐使用 `Slidable` 控件（需要引入 `flutter_slidable` 包）或者长按弹出菜单的方式，而不是在每个 `ListTile` 上都放置两个按钮。`Slidable`（左滑出现删除/编辑按钮）是目前主流且优雅的交互方案。
    -   **删除流程**:
        -   滑动带出"删除"按钮。
        -   点击后，调用 `showDialog` 显示一个 `AlertDialog`，包含"确认删除吗？"等提示。
        -   如果用户确认，则调用 `_transactionService.deleteTransaction(id)`，并在成功后刷新页面状态（`setState`）。
    -   **编辑流程**:
        -   滑动带出"编辑"按钮。
        -   点击后，使用 `Navigator.push` 跳转到 `EditTransactionScreen`，并将要编辑的 `Transaction` 对象作为参数传递过去。
        -   `push` 方法需要 `await`，并检查返回值。如果返回 `true`（表示编辑已保存），则刷新页面状态。`Navigator.push(context, ...).then((result) { if (result == true) _loadHistory(); });`

2.  **[新增] 编辑账单页面 (`lib/presentation/screens/edit_transaction_screen.dart`)**
    -   这是一个 `StatefulWidget`，接收一个 `Transaction` 对象作为构造函数参数。
    -   **UI布局**: 使用 `Scaffold` + `Form` 控件。
        -   `AppBar` 标题为"编辑账单"。
        -   `Form` 包含多个输入组件：
            -   `TextFormField` 用于 `金额` (限制数字输入)。
            -   `TextFormField` 用于 `商家`。
            -   `TextFormField` 用于 `备注` (多行)。
            -   `DatePicker` 用于修改 `日期`。
            -   一个 `SegmentedButton` 或 `ToggleButtons` 用于切换 `支出/收入` 类型。
            -   复用我们之前设计的 `CategoryPicker` 组件来选择分类。
    -   **状态管理**: 在 `initState` 中，使用 `TextEditingController` 来管理各个文本输入框，并将传入的 `Transaction` 对象的初始值赋给它们。
    -   **保存逻辑**:
        -   页面底部有一个"保存"按钮。
        -   点击后，首先验证 `Form` 的有效性（如金额不能为空）。
        -   然后，根据所有输入控件的当前值，创建一个新的 `Transaction` 对象（`id`保持不变）。
        -   调用 `_transactionService.updateTransaction(newTransaction)`。
        -   成功后，`Navigator.pop(context, true)`，返回 `true` 告知前一个页面需要刷新。

## 4. 开发步骤 (Development Steps)

1.  **Step 1: 服务层 (15%工作量)**
    -   [ ] 在 `TransactionService` 中添加 `updateTransaction` 和 `deleteTransaction` 两个公共方法及其SQL实现。
2.  **Step 2: 历史页UI改造 (35%工作量)**
    -   [ ] 在 `pubspec.yaml` 中添加 `flutter_slidable` 依赖。
    -   [ ] 修改 `history_screen.dart`，将 `ListView` 中的 `ListTile` 用 `Slidable` 包裹。
    -   [ ] 实现滑动操作的UI，并添加"编辑"和"删除"的 `ActionPane`。
    -   [ ] 实现删除按钮的点击逻辑，包括弹出 `AlertDialog` 和调用服务层方法。
    -   [ ] 编写好从历史页到编辑页的跳转逻辑，并处理好返回后的刷新。
3.  **Step 3: 编辑页面开发 (50%工作量)**
    -   [ ] 创建 `edit_transaction_screen.dart` 文件，并搭建好 `StatefulWidget` 的基本框架。
    -   [ ] 完整地构建 `Form` 及其所有子输入组件。
    -   [ ] 实现 `initState` 中的数据预填充逻辑。
    -   [ ] 实现"保存"按钮的点击逻辑，包括表单验证、数据封装、服务调用和返回。
    -   [ ] (依赖 `feature-001`) 将 `CategoryPicker` 集成到编辑页面中。

## 5. 风险与考量 (Risks & Considerations)

-   **状态刷新**: 跨页面的状态同步是关键。当一条记录被删除或修改后，不仅"历史账单"页需要刷新，首页的"月度汇总"和"图表"也可能需要同步更新。需要确保 `_loadData()` 这样的刷新方法能被正确地触发。使用 `Navigator.pop(context, true)` 是一个简单有效的方案。
-   **输入验证**: 编辑页面的金额输入框必须有严格的格式验证，防止用户输入非法字符导致应用崩溃。
-   **组件复用**: "编辑账单"页面的 `Form` 部分，与我们未来要做的"手动记账"页面的表单高度相似。在构建时应充分考虑其可复用性，甚至可以将其抽离成一个独立的 `TransactionForm` 组件。 