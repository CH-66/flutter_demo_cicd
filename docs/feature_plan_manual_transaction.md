 # 功能开发计划：手动记账功能

- **功能ID**: `feature-003`
- **功能名称**: 手动记账功能
- **状态**: 规划中
- **负责人**: AI助手
- **依赖功能**: `feature-001` (账单分类管理), `feature-002` (历史账单编辑与删除 - 共享UI组件)

---

## 1. 目标 (Goals)

-   **覆盖全场景**: 为用户提供一种记录无法被通知监听的交易（如现金支付、刷卡、部分网银转账等）的途径。
-   **功能完整性**: 补全一个记账App最基本的功能，使用户可以完全依赖本应用管理所有财务收支。
-   **激活悬浮按钮(FAB)**: 赋予主页上当前闲置的`FloatingActionButton`明确的功能，完善UI交互。

## 2. 功能规格 (Functional Specification)

### 2.1 用户故事

-   **作为一名用户**，在我用现金支付了一杯咖啡后，我希望能立刻点击首页的按钮，快速地把这笔花销记下来。
-   **作为一名用户**，在手动记账时，我希望表单能有一些智能的默认值，比如日期默认是今天，类型默认是支出，以减少我的操作步骤。

### 2.2 核心功能点

1.  **入口**: 用户通过点击主屏幕右下角的`FloatingActionButton`来启动手动记账流程。
2.  **记账页面**:
    -   点击FAB后，应用应跳转到一个新的、全屏的“手动记账”页面。
    -   该页面提供一个完整的表单，用于输入所有交易信息。
3.  **表单字段**:
    -   金额（必填）
    -   商家（选填）
    -   交易类型（支出/收入，默认为支出）
    -   交易分类（必选，默认为“未分类”）
    -   交易日期（必选，默认为当天）
    -   备注（选填）
4.  **保存逻辑**:
    -   用户填写完毕后，点击“保存”按钮。
    -   应用将该条新记录存入数据库。
    -   保存成功后，自动返回主屏幕，并且主屏幕上的月度汇总、图表、最近交易列表应立刻刷新，以反映这条新记录。

## 3. 技术实现方案 (Technical Implementation Plan)

### 3.1 **[核心] UI组件复用**
为避免代码冗余，并统一“手动记账”和“编辑账单”的UI/UX，我们**不应**为它们分别创建表单。
-   **重构/创建 `TransactionForm` 组件**:
    -   在 `lib/presentation/widgets/` 目录下创建一个名为 `transaction_form.dart` 的可复用组件。
    -   这个组件将是一个 `StatefulWidget`，它封装了用于输入金额、商家、备注、日期、类型、分类的所有UI元素和控制器 (`TextEditingController`等)。
    -   它的构造函数应接收一个可选的 `initialTransaction` 对象。
        -   如果 `initialTransaction` 不为 `null`（编辑场景），表单就用它来预填充所有字段。
        -   如果 `initialTransaction` 为 `null`（手动记账场景），表单就使用默认值（如日期为今天，类型为支出）。

### 3.2 服务层 (Service & Database)
-   在 `TransactionService` 中新增核心方法:
    -   `Future<int> addTransaction(Transaction transaction)`:
        -   接收一个不含`id`的`Transaction`对象。
        -   内部执行 `db.insert('transactions', transaction.toMap())`。
        -   返回新插入行的`id`。

### 3.3 UI/UX 层

1.  **主屏幕 (`lib/presentation/screens/home_screen.dart`)**
    -   **FAB逻辑**:
        -   修改 `FloatingActionButton` 的 `onPressed` 回调。
        -   使用 `Navigator.push` 跳转到 `AddTransactionScreen`。
        -   `await` `push` 的结果，如果返回 `true`（表示记账成功），则调用 `_loadData()` 刷新主页。

2.  **[新增] 手动记账页面 (`lib/presentation/screens/add_transaction_screen.dart`)**
    -   这是一个 `StatefulWidget`。
    -   **UI布局**:
        -   `Scaffold` 的 `AppBar` 标题为“记一笔”。
        -   `body` 部分直接调用我们重构出的 `TransactionForm` 组件，并且不向其传递 `initialTransaction` 参数。
    -   **保存逻辑**:
        -   页面底部提供一个“保存”按钮。
        -   点击后，从 `TransactionForm` 的控制器中获取所有用户输入的数据。
        -   进行表单验证（如金额不能为空）。
        -   创建一个新的 `Transaction` 对象。
        -   调用 `_transactionService.addTransaction(newTransaction)`。
        -   成功后，`Navigator.pop(context, true)`，返回 `true` 告知主页需要刷新。

## 4. 开发步骤 (Development Steps)

1.  **Step 1: 服务层实现 (10%工作量)**
    -   [ ] 在 `TransactionService` 中实现 `addTransaction` 方法。
2.  **Step 2: [关键] 表单组件重构 (50%工作量)**
    -   [ ] 创建 `transaction_form.dart` 文件。
    -   [ ] 将 `feature-002` 计划中为“编辑页面”设计的表单UI和逻辑，完全迁移并封装到这个可复用的 `TransactionForm` 组件中。
    -   [ ] 确保该组件能同时处理“编辑”（传入初始值）和“新建”（不传初始值）两种情况。
    -   [ ] **注意**: 这一步可以直接和 `feature-002` 的UI开发步骤合并进行，优先完成此公共组件。
3.  **Step 3: 手动记账页面开发 (30%工作量)**
    -   [ ] 创建 `add_transaction_screen.dart` 文件。
    -   [ ] 在页面中集成 `TransactionForm` 组件。
    -   [ ] 实现“保存”按钮的逻辑，包括数据组装、服务调用和返回。
4.  **Step 4: 主页入口集成 (10%工作量)**
    -   [ ] 在 `home_screen.dart` 中，实现 `FloatingActionButton` 的 `onPressed` 跳转和返回刷新逻辑。

## 5. 风险与考量 (Risks & Considerations)

-   **代码复用失败**: 最大的风险就是没有执行Step 2，导致在“编辑”和“新建”两个页面写了两套几乎一样的表单代码，这将是巨大的技术债。**必须**优先创建可复用的 `TransactionForm` 组件。
-   **用户体验**: 表单的默认值和输入体验至关重要。例如，金额输入框应自动弹出数字键盘。日期选择器应易于使用。
-   **状态同步**: 与编辑功能一样，必须确保新建账单后，所有相关的UI（首页、历史页）都能得到及时、正确的刷新。返回 `true` 的机制是一个简单可靠的实现。