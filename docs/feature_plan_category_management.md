# 功能开发计划：账单分类管理

- **功能ID**: `feature-001`
- **功能名称**: 账单分类管理
- **状态**: 规划中
- **负责人**: AI助手

---

## 1. 目标 (Goals)

本功能旨在让应用从一个简单的"交易记录器"升级为真正的"个人财务分析工具"。通过引入账单分类，用户可以：
-   **结构化管理**自己的支出和收入，告别杂乱无章的流水账。
-   为未来的**数据可视化**和**财务分析**（如"各分类支出占比"）提供数据基础。
-   提高手动记账和账单编辑的**效率和准确性**。

## 2. 功能规格 (Functional Specification)

### 2.1 用户故事

-   **作为一名新用户**，我希望App能预置一些常用的分类（如餐饮、交通、购物），以便我能立即开始使用。
-   **作为一名普通用户**，我希望能在一个专门的页面查看我所有的账单分类。
-   **作为一名高级用户**，我希望能自由地**创建**新分类、**编辑**现有分类（名称、图标、颜色）、以及**删除**不再使用的分类。
-   **作为一名记账用户**，我希望在记账或修改账单时，能方便地从分类列表中选择一个分类。

### 2.2 核心功能点

1.  **分类的增删改查 (CRUD)**
    -   **创建 (Create)**: 用户可以指定 `名称`、`图标` 和 `颜色` 来创建一个新的分类。
    -   **读取 (Read)**: 应用内需要有一个"分类管理"页面，用列表或网格的形式展示所有分类。
    -   **更新 (Update)**: 用户可以修改现有分类的名称、图标、颜色。
    -   **删除 (Delete)**: 用户可以删除一个分类。为防止数据混乱，删除时，所有关联到该分类的交易记录应自动归入"未分类"。
2.  **默认分类**
    -   当用户首次启动应用或数据库初始化时，系统应自动创建一组默认的、通用的分类（如：餐饮、购物、交通、居家、娱乐、医疗、其他收入等）。
3.  **分类选择器**
    -   在所有需要指定分类的UI界面（如记账弹窗、手动记账页、历史账单编辑页），提供一个统一的、可视化的"分类选择器"组件。

## 3. 技术实现方案 (Technical Implementation Plan)

### 3.1 数据模型层 (Data Model)

#### 3.1.1 新增 `Category` 模型 (`lib/models/category.dart`)
```dart
class Category {
  final int? id;
  final String name;
  final int iconCodePoint; // 图标的 CodePoint, e.g., Icons.shopping_cart.codePoint
  final int colorValue;    // 颜色的 aRGB 值, e.g., Colors.blue.value

  Category({
    this.id,
    required this.name,
    required this.iconCodePoint,
    required this.colorValue,
  });

  // toMap, fromMap 方法...
}
```

#### 3.1.2 修改 `Transaction` 模型 (`lib/models/transaction.dart`)
-   **移除** `final String category;` 字段。
-   **新增** `final int categoryId;` 字段，作为指向 `categories` 表的外键。

### 3.2 数据库层 (Service & Database)

#### 3.2.1 数据库表结构
-   新增 `categories` 表:
    -   `id` INTEGER PRIMARY KEY AUTOINCREMENT
    -   `name` TEXT NOT NULL
    -   `icon_code_point` INTEGER NOT NULL
    -   `color_value` INTEGER NOT NULL
-   修改 `transactions` 表:
    -   新增 `category_id` INTEGER
    -   (迁移完成后) 可考虑移除旧的 `category` 字段。

#### 3.2.2 **[高风险]** 数据库迁移方案
这是本次升级最关键、风险最高的部分，必须确保现有用户的数据无损迁移。
-   在 `TransactionService` 初始化时，引入数据库版本管理。
-   **升级逻辑 (`onUpgrade`)**:
    1.  **创建新表**: `CREATE TABLE categories ...`。
    2.  **填充默认分类**: 将预设的分类数据 `INSERT` 到 `categories` 表中，并记录"未分类"的`id`。
    3.  **提取旧数据**: `SELECT DISTINCT category FROM transactions`，获取所有用户自定义过的旧分类名称。
    4.  **迁移旧分类**: 遍历这些旧分类名称，为它们在 `categories` 表中创建新条目（可使用默认图标/颜色）。
    5.  **添加新列**: `ALTER TABLE transactions ADD COLUMN category_id INTEGER;`
    6.  **更新外键**: `UPDATE transactions SET category_id = (SELECT id FROM categories WHERE categories.name = transactions.category);`。这是一个核心步骤，将旧的文本分类关联到新的ID上。
    7.  **处理孤儿数据**: 为防止意外，最后再执行一次 `UPDATE transactions SET category_id = [未分类ID] WHERE category_id IS NULL;`。

#### 3.2.3 新增服务层方法 (`TransactionService`)
-   `Future<List<Category>> getAllCategories()`
-   `Future<int> addCategory(Category category)`
-   `Future<void> updateCategory(Category category)`
-   `Future<void> deleteCategory(int id)`
-   `Future<void> _handleDeleteCategory(int id)`: 内部方法，在删除分类时，将关联的交易`categoryId`更新为"未分类"的ID。

### 3.3 UI/UX 层

1.  **分类管理页面 (`lib/presentation/screens/category_management_screen.dart`)**
    -   从 `SettingsScreen` (设置页) 跳转过来。
    -   使用 `FutureBuilder` + `getAllCategories()` 来展示一个 `GridView` 或 `ListView`。
    -   每个Item显示分类的图标、颜色和名称，并提供"编辑"和"删除"按钮。
    -   页面右上角提供"新增"按钮，点击后弹出 `_CategoryEditorDialog`。
2.  **分类编辑/创建对话框 (`_CategoryEditorDialog`)**
    -   一个 `StatefulWidget` 的对话框。
    -   包含一个 `TextField` 用于输入名称。
    -   包含一个图标选择器（可以是网格展示的预选图标）。
    -   包含一个颜色选择器（可以是网格展示的预选颜色）。
3.  **分类选择器组件 (`lib/presentation/widgets/category_picker.dart`)**
    -   一个可复用的组件。
    -   平时显示当前选中的分类（图标+名称）。
    -   点击后弹出一个 `showModalBottomSheet`，其中用 `GridView` 展示所有可选分类，供用户点选。
4.  **UI集成**
    -   在记账确认弹窗 (`_ConfirmationDialogContent`) 中，加入该 `CategoryPicker` 组件。
    -   在未来的手动记账页和编辑页中，复用该组件。

## 4. 开发步骤 (Development Steps)

1.  **Step 1: 模型与数据库 (40%工作量)**
    -   [ ] 创建 `category.dart` 文件并定义 `Category` 模型。
    -   [ ] 修改 `transaction.dart` 中的 `Transaction` 模型。
    -   [ ] 在 `TransactionService` 中，实现数据库的 `onUpgrade` 迁移逻辑。这是**首要且最关键**的一步。
    -   [ ] 在 `TransactionService` 中，实现 `Category` 相关的CRUD方法。
2.  **Step 2: 后端逻辑适配 (10%工作量)**
    -   [ ] 审查所有旧的、使用 `transaction.category` 的地方（如首页汇总逻辑），将其修改为基于 `categoryId` 的新逻辑（可能需要`JOIN`查询或二次查询）。
3.  **Step 3: UI - 分类管理 (30%工作量)**
    -   [ ] 创建 `category_management_screen.dart`，并实现其基本布局和跳转逻辑。
    -   [ ] 实现分类列表的展示。
    -   [ ] 实现 `_CategoryEditorDialog`，并完成新建和编辑功能。
    -   [ ] 实现删除功能，并确保有二次确认。
4.  **Step 4: UI - 集成 (20%工作量)**
    -   [ ] 创建 `category_picker.dart` 组件。
    -   [ ] 将 `CategoryPicker` 集成到记账确认弹窗中。
    -   [ ] 确保记账时，选择的 `categoryId` 能被正确保存。

## 5. 风险与考量 (Risks & Considerations)

-   **数据迁移失败**: 这是最大的风险。需要进行充分的测试，覆盖新老用户、有无数据等各种场景。可以考虑在迁移前进行数据库备份。
-   **性能问题**: 如果交易记录非常多，`JOIN` 查询可能会影响性能。在 `TransactionService` 中获取交易列表时，需要考虑是直接 `JOIN` 查询出分类名，还是先查出交易，再根据 `categoryId` 批量查询分类信息。后者通常性能更好。
-   **用户体验**: 删除分类时的策略需要明确告知用户（即"账单不会被删除，而是会被归为未分类"）。 