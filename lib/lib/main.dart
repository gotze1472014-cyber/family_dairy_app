import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // تهيئة الفايربيز للربط السحابي اللحظي
  try {
    await Firebase.initializeApp();
  } catch (e) {
    debugPrint('Firebase initialization error: $e');
  }
  runApp(const FamilyDairyApp());
}

String formatNumber(dynamic number) {
  if (number == null) return '0';
  double val = number is int ? number.toDouble() : (number as double);
  String str = val.toStringAsFixed(0);
  RegExp reg = RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))');
  return str.replaceAllMapped(reg, (Match m) => '${m[1]},');
}

String formatDecimal(dynamic number) {
  if (number == null) return '0';
  double val = number is int ? number.toDouble() : (number as double);
  if (val == val.roundToDouble()) {
    return formatNumber(val.toInt());
  }
  return val.toStringAsFixed(2);
}

// إعدادات التطبيق العامة والصلاحيات
class AppSettings {
  static String appLanguage = 'العربية';
  static bool subAccountCanDeleteInvoice = false;
  static bool subAccountCanModifyPrices = false;
  static bool subAccountCanAccessReports = true;
  static String adminPassword = '1234';
  static String subAccountPassword = '0000';
}

class FamilyDairyApp extends StatefulWidget {
  const FamilyDairyApp({super.key});

  @override
  State<FamilyDairyApp> createState() => _FamilyDairyAppState();
}

class _FamilyDairyAppState extends State<FamilyDairyApp> {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'ألبان وأجبان العائلة',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: Colors.amber,
          primary: Colors.amber.shade800,
          secondary: Colors.orangeAccent,
        ),
        useMaterial3: true,
        fontFamily: 'Roboto',
        cardTheme: CardThemeData(
          elevation: 2,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      ),
      home: const LoginScreen(),
    );
  }
}

// ================= 1. Models =================
class ProductModel {
  String id;
  String name;
  double purchasePrice;
  double sellingPrice;
  double stockQuantity;
  String unit;
  String barcode;
  bool canBeUsedAsIngredient;
  bool isManufactured;
  double baseIngredientRequiredPerUnit;
  double minStockAlert;
  String notes;
  String category; // ألبان وأجبان، غذائيات، بسكويت
  
  bool isSplitProduct; 
  double splitFactor; 
  String subUnitName; 
  double unitSellingPrice; 
  double maxCapacity;

  ProductModel({
    required this.id,
    required this.name,
    required this.purchasePrice,
    required this.sellingPrice,
    required this.stockQuantity,
    this.unit = 'كيلو',
    this.barcode = '',
    this.canBeUsedAsIngredient = false,
    this.isManufactured = false,
    this.baseIngredientRequiredPerUnit = 0.0,
    this.minStockAlert = 5.0,
    this.notes = '',
    this.category = 'ألبان وأجبان',
    this.isSplitProduct = false,
    this.splitFactor = 1.0,
    this.subUnitName = 'قطعة',
    this.unitSellingPrice = 0.0,
    this.maxCapacity = 100.0,
  });

  Map<String, dynamic> toJson() {
    return {
      'id': id, 'name': name, 'purchasePrice': purchasePrice, 'sellingPrice': sellingPrice,
      'stockQuantity': stockQuantity, 'unit': unit, 'barcode': barcode,
      'canBeUsedAsIngredient': canBeUsedAsIngredient, 'isManufactured': isManufactured,
      'baseIngredientRequiredPerUnit': baseIngredientRequiredPerUnit, 'minStockAlert': minStockAlert,
      'notes': notes, 'category': category, 'isSplitProduct': isSplitProduct,
      'splitFactor': splitFactor, 'subUnitName': subUnitName, 'unitSellingPrice': unitSellingPrice,
      'maxCapacity': maxCapacity,
    };
  }

  factory ProductModel.fromJson(Map<String, dynamic> json) {
    return ProductModel(
      id: json['id'] ?? '', name: json['name'] ?? '',
      purchasePrice: (json['purchasePrice'] as num?)?.toDouble() ?? 0.0,
      sellingPrice: (json['sellingPrice'] as num?)?.toDouble() ?? 0.0,
      stockQuantity: (json['stockQuantity'] as num?)?.toDouble() ?? 0.0,
      unit: json['unit'] ?? 'كيلو', barcode: json['barcode'] ?? '',
      canBeUsedAsIngredient: json['canBeUsedAsIngredient'] ?? false,
      isManufactured: json['isManufactured'] ?? false,
      baseIngredientRequiredPerUnit: (json['baseIngredientRequiredPerUnit'] as num?)?.toDouble() ?? 0.0,
      minStockAlert: (json['minStockAlert'] as num?)?.toDouble() ?? 5.0,
      notes: json['notes'] ?? '', category: json['category'] ?? 'ألبان وأجبان',
      isSplitProduct: json['isSplitProduct'] ?? false,
      splitFactor: (json['splitFactor'] as num?)?.toDouble() ?? 1.0,
      subUnitName: json['subUnitName'] ?? 'قطعة',
      unitSellingPrice: (json['unitSellingPrice'] as num?)?.toDouble() ?? 0.0,
      maxCapacity: (json['maxCapacity'] as num?)?.toDouble() ?? 100.0,
    );
  }
}

class SupplierModel {
  String id;
  String name;
  String phone;
  String category;

  SupplierModel({required this.id, required this.name, required this.phone, required this.category});

  Map<String, dynamic> toJson() => {'id': id, 'name': name, 'phone': phone, 'category': category};

  factory SupplierModel.fromJson(Map<String, dynamic> json) => SupplierModel(
    id: json['id'] ?? '', name: json['name'] ?? '', phone: json['phone'] ?? '', category: json['category'] ?? '',
  );
}

class InvoiceItem {
  ProductModel product;
  double quantity;
  double priceUsed;
  String unitLabelUsed;

  double get total => quantity * priceUsed;
  double get profit => total - (quantity * product.purchasePrice);

  InvoiceItem({required this.product, required this.quantity, required this.priceUsed, required this.unitLabelUsed});

  Map<String, dynamic> toJson() => {
    'productId': product.id,
    'productName': product.name,
    'quantity': quantity,
    'priceUsed': priceUsed,
    'unitLabelUsed': unitLabelUsed,
  };
}

enum InvoiceType { sales, purchase }

class InvoiceModel {
  String id;
  String partyName;
  List<InvoiceItem> items;
  double subTotal;
  double discountOrExtra;
  double totalAmount;
  double totalProfit;
  DateTime date;
  InvoiceType type;
  bool isDebt;

  InvoiceModel({
    required this.id, required this.partyName, required this.items, required this.subTotal,
    this.discountOrExtra = 0, required this.totalAmount, required this.totalProfit,
    required this.date, required this.type, this.isDebt = false,
  });

  Map<String, dynamic> toJson() => {
    'id': id,
    'partyName': partyName,
    'items': items.map((i) => i.toJson()).toList(),
    'subTotal': subTotal,
    'discountOrExtra': discountOrExtra,
    'totalAmount': totalAmount,
    'totalProfit': totalProfit,
    'date': date.toIso8601String(),
    'type': type == InvoiceType.sales ? 'sales' : 'purchase',
    'isDebt': isDebt,
  };
}

class PaymentVoucherModel {
  String title;
  double amount;
  String details;
  DateTime date;

  PaymentVoucherModel({required this.title, required this.amount, required this.details, required this.date});

  Map<String, dynamic> toJson() => {
    'title': title, 'amount': amount, 'details': details, 'date': date.toIso8601String()
  };

  factory PaymentVoucherModel.fromJson(Map<String, dynamic> json) => PaymentVoucherModel(
    title: json['title'] ?? '',
    amount: (json['amount'] as num?)?.toDouble() ?? 0.0,
    details: json['details'] ?? '',
    date: json['date'] != null ? DateTime.parse(json['date']) : DateTime.now(),
  );
}

class DebtPaymentModel {
  String partyName;
  double amountPaid;
  DateTime date;
  bool isCustomer;

  DebtPaymentModel({required this.partyName, required this.amountPaid, required this.date, required this.isCustomer});

  Map<String, dynamic> toJson() => {
    'partyName': partyName, 'amountPaid': amountPaid, 'date': date.toIso8601String(), 'isCustomer': isCustomer
  };

  factory DebtPaymentModel.fromJson(Map<String, dynamic> json) => DebtPaymentModel(
    partyName: json['partyName'] ?? '',
    amountPaid: (json['amountPaid'] as num?)?.toDouble() ?? 0.0,
    date: json['date'] != null ? DateTime.parse(json['date']) : DateTime.now(),
    isCustomer: json['isCustomer'] ?? true,
  );
}

// ================= 2. Login Screen =================
class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final TextEditingController _passController = TextEditingController();
  bool _isAdmin = true;

  void _login() {
    String pass = _passController.text.trim();
    if (_isAdmin) {
      if (pass == AppSettings.adminPassword || pass.isEmpty) {
        Navigator.pushReplacement(context, MaterialPageRoute(builder: (c) => const MainDashboardScreen(isAdmin: true)));
      } else {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('كلمة مرور المدير خاطئة'), backgroundColor: Colors.red));
      }
    } else {
      if (pass == AppSettings.subAccountPassword || pass.isEmpty) {
        Navigator.pushReplacement(context, MaterialPageRoute(builder: (c) => const MainDashboardScreen(isAdmin: false)));
      } else {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('كلمة مرور الحساب الفرعي خاطئة'), backgroundColor: Colors.red));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: Colors.amber.shade50,
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(20.0),
            child: Card(
              elevation: 8,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
              child: Padding(
                padding: const EdgeInsets.all(24.0),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(color: Colors.amber.shade100, shape: BoxShape.circle),
                      child: const Icon(Icons.kebab_dining, size: 50, color: Colors.brown),
                    ),
                    const SizedBox(height: 12),
                    const Text('ألبان وأجبان العائلة', style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.brown)),
                    const Text('إدارة الألبان والأجبان بحرفية وسهولة', style: TextStyle(fontSize: 12, color: Colors.grey)),
                    const SizedBox(height: 20),
                    ToggleButtons(
                      isSelected: [_isAdmin, !_isAdmin],
                      onPressed: (index) => setState(() => _isAdmin = index == 0),
                      borderRadius: BorderRadius.circular(10),
                      selectedColor: Colors.white,
                      fillColor: Colors.amber.shade800,
                      children: const [
                        Padding(padding: EdgeInsets.symmetric(horizontal: 20, vertical: 8), child: Text('حساب مدير')),
                        Padding(padding: EdgeInsets.symmetric(horizontal: 20, vertical: 8), child: Text('نقطة مبيع سحابية')),
                      ],
                    ),
                    const SizedBox(height: 20),
                    TextField(
                      controller: _passController,
                      obscureText: true,
                      keyboardType: TextInputType.number,
                      decoration: InputDecoration(
                        labelText: 'أدخل كلمة المرور',
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                        prefixIcon: const Icon(Icons.lock),
                      ),
                    ),
                    const SizedBox(height: 20),
                    ElevatedButton(
                      style: ElevatedButton.styleFrom(backgroundColor: Colors.amber.shade800, foregroundColor: Colors.white, minimumSize: const Size.fromHeight(50), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
                      onPressed: _login,
                      child: const Text('تسجيل الدخول', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ================= 3. Main Dashboard (مع ربط Firebase Cloud Sync) =================
class MainDashboardScreen extends StatefulWidget {
  final bool isAdmin;
  const MainDashboardScreen({super.key, required this.isAdmin});

  @override
  State<MainDashboardScreen> createState() => _MainDashboardScreenState();
}

class _MainDashboardScreenState extends State<MainDashboardScreen> {
  final List<ProductModel> _productsDB = [
    ProductModel(id: '1', name: 'حليب طازج (خام)', purchasePrice: 7000, sellingPrice: 8500, stockQuantity: 200, unit: 'ليتر', canBeUsedAsIngredient: true, category: 'ألبان وأجبان', maxCapacity: 500),
    ProductModel(id: '2', name: 'لبن رائب', purchasePrice: 8000, sellingPrice: 10000, stockQuantity: 60, unit: 'كيلو', canBeUsedAsIngredient: true, isManufactured: true, baseIngredientRequiredPerUnit: 1.1, category: 'ألبان وأجبان', maxCapacity: 200),
    ProductModel(id: '3', name: 'صحن بيض', purchasePrice: 30000, sellingPrice: 35000, stockQuantity: 10, unit: 'صحن', isSplitProduct: true, splitFactor: 30, subUnitName: 'بيضة', unitSellingPrice: 1300, category: 'غذائيات', maxCapacity: 50),
    ProductModel(id: '4', name: 'بسكويت شوكولاتة', purchasePrice: 5000, sellingPrice: 7000, stockQuantity: 40, unit: 'باكيت', category: 'بسكويت', maxCapacity: 100),
  ];

  final List<SupplierModel> _suppliersDB = [
    SupplierModel(id: '1', name: 'مزرعة الخير (حليب)', phone: '0933111222', category: 'حليب خام'),
  ];

  final List<InvoiceModel> _invoices = [];
  final List<PaymentVoucherModel> _vouchers = [];
  final List<DebtPaymentModel> _debtPayments = [];

  // دالة لحفظ الفاتورة ورفعها للسحابة فوراً عبر Firebase Firestore
  Future<void> _addInvoice(InvoiceModel invoice, bool isDebt) async {
    setState(() {
      invoice.isDebt = isDebt;
      _invoices.add(invoice);
      for (var item in invoice.items) {
        if (invoice.type == InvoiceType.sales) {
          item.product.stockQuantity -= item.quantity;
        } else {
          item.product.stockQuantity += item.quantity;
        }
      }
    });

    // رفع الفاتورة سحابياً لتتزامن عند المدير في أي مكان
    try {
      await FirebaseFirestore.instance.collection('invoices').doc(invoice.id).set(invoice.toJson());
    } catch (e) {
      debugPrint('Cloud sync error (Invoice): $e');
    }
  }

  Future<void> _deleteInvoice(InvoiceModel invoice) async {
    if (!widget.isAdmin && !AppSettings.subAccountCanDeleteInvoice) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('عذراً، الحساب الفرعي لا يمتلك صلاحية الحذف'), backgroundColor: Colors.red));
      return;
    }
    setState(() {
      for (var item in invoice.items) {
        if (invoice.type == InvoiceType.sales) {
          item.product.stockQuantity += item.quantity;
        } else {
          item.product.stockQuantity -= item.quantity;
        }
      }
      _invoices.removeWhere((i) => i.id == invoice.id);
    });

    try {
      await FirebaseFirestore.instance.collection('invoices').doc(invoice.id).delete();
    } catch (e) {
      debugPrint('Cloud sync error (Delete): $e');
    }
  }

  void _navigateTo(Widget screen) {
    Navigator.push(context, MaterialPageRoute(builder: (c) => screen));
  }

  @override
  Widget build(BuildContext context) {
    DateTime now = DateTime.now();
    String formattedDate = "${now.year}/${now.month.toString().padLeft(2, '0')}/${now.day.toString().padLeft(2, '0')}";
    String formattedTime = "${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}";

    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        appBar: AppBar(
          backgroundColor: Colors.amber.shade700,
          foregroundColor: Colors.white,
          title: Text(widget.isAdmin ? 'لوحة التحكم (المدير - متزامن سحابياً)' : 'نقطة المبيع (متزامن مع السحاب)'),
          actions: [
            IconButton(
              icon: const Icon(Icons.settings),
              tooltip: 'الإعدادات والربط',
              onPressed: () => _navigateTo(AppSettingsWidget(isAdmin: widget.isAdmin, onUpdate: () => setState(() {}))),
            ),
            IconButton(
              icon: const Icon(Icons.logout),
              tooltip: 'تسجيل خروج',
              onPressed: () => Navigator.pushReplacement(context, MaterialPageRoute(builder: (c) => const LoginScreen())),
            )
          ],
        ),
        body: Padding(
          padding: const EdgeInsets.all(12.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                decoration: BoxDecoration(
                  gradient: LinearGradient(colors: [Colors.amber.shade100, Colors.amber.shade50]),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.amber.shade300),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(children: [const Icon(Icons.calendar_today, size: 16, color: Colors.brown), const SizedBox(width: 5), Text(formattedDate, style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.brown))]),
                    Row(children: [const Icon(Icons.cloud_done, size: 16, color: Colors.teal), const SizedBox(width: 5), Text('متصل بالخادم السحابي', style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.teal))]),
                    Row(children: [const Icon(Icons.access_time, size: 16, color: Colors.brown), const SizedBox(width: 5), Text(formattedTime, style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.brown))]),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              const Text('اختر القسم المطلوب:', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.blueGrey)),
              const SizedBox(height: 10),
              Expanded(
                child: GridView.count(
                  crossAxisCount: 2,
                  crossAxisSpacing: 12,
                  mainAxisSpacing: 12,
                  children: [
                    _buildDashboardCard('إدارة المواد (كتالوج)', Icons.category, Colors.brown, () {
                      _navigateTo(ProductCatalogWidget(products: _productsDB, onUpdate: () => setState(() {}), isAdmin: widget.isAdmin));
                    }),
                    _buildDashboardCard('إدارة المخزن والترتيب', Icons.inventory_2, Colors.orange.shade800, () {
                      _navigateTo(StockManagementWidget(
                        products: _productsDB,
                        vouchers: _vouchers,
                        suppliers: _suppliersDB,
                        onUpdate: () => setState(() {}),
                        isAdmin: widget.isAdmin,
                      ));
                    }),
                    _buildDashboardCard('فاتورة مبيع جديدة', Icons.point_of_sale, Colors.green, () {
                      _navigateTo(Scaffold(
                        appBar: AppBar(title: const Text('فاتورة مبيع جديدة (نقطة مبيع)'), backgroundColor: Colors.green),
                        body: InvoiceBuilderWidget(type: InvoiceType.sales, products: _productsDB, suppliers: _suppliersDB, onSubmit: _addInvoice),
                      ));
                    }),
                    if (widget.isAdmin) ...[
                      _buildDashboardCard('فاتورة شراء جديدة', Icons.shopping_bag, Colors.blue, () {
                        _navigateTo(Scaffold(
                          appBar: AppBar(title: const Text('فاتورة شراء بضاعة'), backgroundColor: Colors.blue),
                          body: InvoiceBuilderWidget(type: InvoiceType.purchase, products: _productsDB, suppliers: _suppliersDB, onSubmit: _addInvoice),
                        ));
                      }),
                      _buildDashboardCard('وحدة التصنيع', Icons.precision_manufacturing, Colors.teal, () {
                        _navigateTo(Scaffold(
                          appBar: AppBar(title: const Text('وحدة التصنيع والتشغيل'), backgroundColor: Colors.teal),
                          body: AdvancedProductionWidget(products: _productsDB, vouchers: _vouchers, onUpdate: () => setState(() {}), isAdmin: widget.isAdmin),
                        ));
                      }),
                      _buildDashboardCard('إدارة الموردين', Icons.local_shipping, Colors.indigo, () {
                        _navigateTo(SuppliersWidget(suppliers: _suppliersDB, invoices: _invoices, onUpdate: () => setState(() {}), isAdmin: widget.isAdmin));
                      }),
                    ],
                    _buildDashboardCard('إدارة فواتير المبيع', Icons.receipt_long, Colors.green.shade700, () {
                      _navigateTo(InvoicesManagerWidget(invoices: _invoices, type: InvoiceType.sales, onDelete: _deleteInvoice, isAdmin: widget.isAdmin));
                    }),
                    _buildDashboardCard('الديون والآجل', Icons.account_balance_wallet, Colors.deepOrange, () {
                      _navigateTo(Scaffold(
                        appBar: AppBar(title: const Text('سجل الديون والذمم'), backgroundColor: Colors.deepOrange),
                        body: DebtsWidget(invoices: _invoices, debtPayments: _debtPayments, onAddPayment: (p) => setState(() => _debtPayments.add(p))),
                      ));
                    }),
                    _buildDashboardCard('سندات المصاريف', Icons.receipt, Colors.red.shade700, () {
                      _navigateTo(PaymentVouchersWidget(vouchers: _vouchers, onUpdate: () => setState(() {}), isAdmin: widget.isAdmin));
                    }),
                    _buildDashboardCard('التقارير السحابية والأرباح', Icons.analytics, Colors.purple, () {
                      if (!widget.isAdmin && !AppSettings.subAccountCanAccessReports) {
                        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('غير مسموح للحساب الفرعي بالدخول للتقارير'), backgroundColor: Colors.red));
                        return;
                      }
                      _navigateTo(Scaffold(
                        appBar: AppBar(title: const Text('التقارير السحابية والأرباح'), backgroundColor: Colors.purple),
                        body: ReportsAndBackupWidget(
                          products: _productsDB,
                          suppliers: _suppliersDB,
                          invoices: _invoices,
                          vouchers: _vouchers,
                          debtPayments: _debtPayments,
                          onUpdate: () => setState(() {}),
                          onDeleteInvoice: _deleteInvoice,
                          isAdmin: widget.isAdmin,
                        ),
                      ));
                    }),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDashboardCard(String title, IconData icon, Color color, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        decoration: BoxDecoration(
          color: color.withOpacity(0.08),
          border: Border.all(color: color.withOpacity(0.3), width: 1.5),
          borderRadius: BorderRadius.circular(16),
          boxShadow: [BoxShadow(color: color.withOpacity(0.05), blurRadius: 5, offset: const Offset(0, 3))],
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 42, color: color),
            const SizedBox(height: 10),
            Text(title, textAlign: TextAlign.center, style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: color)),
          ],
        ),
      ),
    );
  }
}

// ================= 4. Barcode Scanner Screen =================
class BarcodeScannerScreen extends StatelessWidget {
  const BarcodeScannerScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('مسح باركود المادة')),
      body: MobileScanner(
        onDetect: (capture) {
          final List<Barcode> barcodes = capture.barcodes;
          for (final barcode in barcodes) {
            if (barcode.rawValue != null) {
              Navigator.pop(context, barcode.rawValue);
              break;
            }
          }
        },
      ),
    );
  }
}

// ================= 5. Product Catalog =================
class ProductCatalogWidget extends StatefulWidget {
  final List<ProductModel> products;
  final VoidCallback onUpdate;
  final bool isAdmin;
  final ProductModel? targetProductToEdit;

  const ProductCatalogWidget({super.key, required this.products, required this.onUpdate, required this.isAdmin, this.targetProductToEdit});

  @override
  State<ProductCatalogWidget> createState() => _ProductCatalogWidgetState();
}

class _ProductCatalogWidgetState extends State<ProductCatalogWidget> {
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _buyPriceController = TextEditingController();
  final TextEditingController _sellPriceController = TextEditingController();
  final TextEditingController _barcodeController = TextEditingController();
  final TextEditingController _baseRatioController = TextEditingController(text: '1.0');
  final TextEditingController _minAlertController = TextEditingController(text: '5.0');
  final TextEditingController _notesController = TextEditingController();
  final TextEditingController _categoryController = TextEditingController(text: 'ألبان وأجبان');
  final TextEditingController _maxCapacityController = TextEditingController(text: '100');
  
  final TextEditingController _splitFactorController = TextEditingController(text: '30');
  final TextEditingController _subUnitNameController = TextEditingController(text: 'بيضة');
  final TextEditingController _unitSellingPriceController = TextEditingController(text: '0');

  String _selectedUnit = 'كيلو';
  bool _canBeUsedAsIngredient = false;
  bool _isManufactured = false;
  bool _isSplitProduct = false;
  final List<String> _unitsList = ['كيلو', 'غرام', 'ليتر', 'صحن', 'كرتونة', 'علبة', 'قطعة', 'كيس', 'باكيت'];
  final List<String> _categoriesList = ['ألبان وأجبان', 'غذائيات', 'بسكويت'];
  String _filterCategory = 'الكل';

  @override
  void initState() {
    super.initState();
    if (widget.targetProductToEdit != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _openProductCardSheet(product: widget.targetProductToEdit);
      });
    }
  }

  Future<void> _scanBarcodeForCard(StateSetter setSheetState) async {
    final scannedCode = await Navigator.push<String>(context, MaterialPageRoute(builder: (context) => const BarcodeScannerScreen()));
    if (scannedCode != null) {
      setSheetState(() => _barcodeController.text = scannedCode);
    }
  }

  void _openProductCardSheet({ProductModel? product}) {
    if (product != null) {
      _nameController.text = product.name;
      _buyPriceController.text = product.purchasePrice.toString();
      _sellPriceController.text = product.sellingPrice.toString();
      _barcodeController.text = product.barcode;
      _selectedUnit = product.unit;
      _canBeUsedAsIngredient = product.canBeUsedAsIngredient;
      _isManufactured = product.isManufactured;
      _baseRatioController.text = product.baseIngredientRequiredPerUnit.toString();
      _minAlertController.text = product.minStockAlert.toString();
      _notesController.text = product.notes;
      _categoryController.text = product.category;
      _isSplitProduct = product.isSplitProduct;
      _splitFactorController.text = product.splitFactor.toString();
      _subUnitNameController.text = product.subUnitName;
      _unitSellingPriceController.text = product.unitSellingPrice.toString();
      _maxCapacityController.text = product.maxCapacity.toString();
    } else {
      _nameController.clear();
      _buyPriceController.clear();
      _sellPriceController.clear();
      _barcodeController.clear();
      _selectedUnit = 'كيلو';
      _canBeUsedAsIngredient = false;
      _isManufactured = false;
      _isSplitProduct = false;
      _baseRatioController.text = '1.0';
      _minAlertController.text = '5.0';
      _notesController.clear();
      _categoryController.text = 'ألبان وأجبان';
      _maxCapacityController.text = '100';
      _splitFactorController.text = '30';
      _subUnitNameController.text = 'بيضة';
      _unitSellingPriceController.text = '0';
    }

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setSheetState) {
            double buyP = double.tryParse(_buyPriceController.text) ?? 0;
            double sellP = double.tryParse(_sellPriceController.text) ?? 0;
            double estimatedProfit = sellP - buyP;
            double profitMargin = sellP > 0 ? (estimatedProfit / sellP) * 100 : 0;

            return Directionality(
              textDirection: TextDirection.rtl,
              child: Padding(
                padding: EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom, top: 20, left: 16, right: 16),
                child: SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Row(children: [const Icon(Icons.category, color: Colors.brown), const SizedBox(width: 8), Text(product == null ? 'إضافة بطاقة مادة جديدة' : 'تعديل بطاقة مادة', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.brown))]),
                          IconButton(icon: const Icon(Icons.close), onPressed: () => Navigator.pop(ctx)),
                        ],
                      ),
                      const Divider(),
                      const Text('1. المعلومات الأساسية والصنف', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.amber)),
                      const SizedBox(height: 8),
                      TextField(controller: _nameController, decoration: const InputDecoration(labelText: 'اسم المادة', border: OutlineInputBorder(), isDense: true)),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Expanded(child: TextField(controller: _barcodeController, decoration: const InputDecoration(labelText: 'الباركود', border: OutlineInputBorder(), isDense: true))),
                          const SizedBox(width: 6),
                          IconButton(icon: const Icon(Icons.qr_code_scanner, color: Colors.indigo), onPressed: () => _scanBarcodeForCard(setSheetState)),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Expanded(
                            child: DropdownButtonFormField<String>(
                              value: _categoriesList.contains(_categoryController.text) ? _categoryController.text : 'ألبان وأجبان',
                              decoration: const InputDecoration(labelText: 'الصنف الأساسي', border: OutlineInputBorder(), isDense: true),
                              items: _categoriesList.map((c) => DropdownMenuItem(value: c, child: Text(c, style: const TextStyle(fontSize: 13)))).toList(),
                              onChanged: (v) => setSheetState(() => _categoryController.text = v!),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: DropdownButtonFormField<String>(
                              value: _selectedUnit,
                              decoration: const InputDecoration(labelText: 'وحدة القياس', border: OutlineInputBorder(), isDense: true),
                              items: _unitsList.map((u) => DropdownMenuItem(value: u, child: Text(u, style: const TextStyle(fontSize: 13)))).toList(),
                              onChanged: (v) => setSheetState(() => _selectedUnit = v!),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      const Text('2. الأسعار', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.green)),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Expanded(child: TextField(controller: _buyPriceController, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'سعر التكلفة', border: OutlineInputBorder(), isDense: true), onChanged: (v) => setSheetState(() {}))),
                          const SizedBox(width: 8),
                          Expanded(child: TextField(controller: _sellPriceController, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'سعر البيع', border: OutlineInputBorder(), isDense: true), onChanged: (v) => setSheetState(() {}))),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(color: Colors.green.shade50, borderRadius: BorderRadius.circular(8), border: Border.all(color: Colors.green.shade200)),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text('الربح التقديري: ${formatNumber(estimatedProfit)} ل.س', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.green)),
                            Text('النسبة: ${formatDecimal(profitMargin)}%', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.green)),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),
                      const Text('3. خيارات التجزئة والكسور', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.brown)),
                      CheckboxListTile(
                        dense: true,
                        title: const Text('تفعيل التجزئة (جملة ومفرق)'),
                        value: _isSplitProduct,
                        onChanged: (v) => setSheetState(() => _isSplitProduct = v ?? false),
                      ),
                      if (_isSplitProduct) ...[
                        Row(
                          children: [
                            Expanded(child: TextField(controller: _splitFactorController, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'عدد القطع (30)', border: OutlineInputBorder(), isDense: true))),
                            const SizedBox(width: 8),
                            Expanded(child: TextField(controller: _subUnitNameController, decoration: const InputDecoration(labelText: 'اسم القطعة (بيضة)', border: OutlineInputBorder(), isDense: true))),
                          ],
                        ),
                        const SizedBox(height: 8),
                        TextField(controller: _unitSellingPriceController, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'سعر بيع القطعة مفرق', border: OutlineInputBorder(), isDense: true)),
                      ],
                      const SizedBox(height: 16),
                      const Text('4. إعدادات التصنيع والخام', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.teal)),
                      CheckboxListTile(
                        dense: true,
                        title: const Text('مادة خام قابلة للاستخدام بالتصنيع'),
                        value: _canBeUsedAsIngredient,
                        onChanged: (v) => setSheetState(() => _canBeUsedAsIngredient = v ?? false),
                      ),
                      CheckboxListTile(
                        dense: true,
                        title: const Text('مادة تنتج عبر وحدة التصنيع'),
                        value: _isManufactured,
                        onChanged: (v) => setSheetState(() => _isManufactured = v ?? false),
                      ),
                      if (_isManufactured) ...[
                        const SizedBox(height: 6),
                        TextField(
                          controller: _baseRatioController,
                          keyboardType: TextInputType.number,
                          decoration: InputDecoration(
                            labelText: 'كمية الخام المطلوب لتصنيع 1 ${_selectedUnit}',
                            border: const OutlineInputBorder(),
                            isDense: true,
                          ),
                        ),
                      ],
                      const SizedBox(height: 16),
                      const Text('5. المخزن والتنبيهات', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.deepOrange)),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Expanded(child: TextField(controller: _minAlertController, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'حد التنبيه', border: OutlineInputBorder(), isDense: true))),
                          const SizedBox(width: 8),
                          Expanded(child: TextField(controller: _maxCapacityController, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'السعة القصوى', border: OutlineInputBorder(), isDense: true))),
                        ],
                      ),
                      const SizedBox(height: 20),
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton.icon(
                          style: ElevatedButton.styleFrom(backgroundColor: Colors.brown, foregroundColor: Colors.white, minimumSize: const Size.fromHeight(48)),
                          onPressed: () {
                            if (_nameController.text.isNotEmpty) {
                              setState(() {
                                double maxCap = double.tryParse(_maxCapacityController.text) ?? 100.0;
                                if (product == null) {
                                  widget.products.add(ProductModel(
                                    id: DateTime.now().toString(),
                                    name: _nameController.text.trim(),
                                    purchasePrice: double.tryParse(_buyPriceController.text) ?? 0,
                                    sellingPrice: double.tryParse(_sellPriceController.text) ?? 0,
                                    stockQuantity: 0,
                                    barcode: _barcodeController.text.trim(),
                                    unit: _selectedUnit,
                                    canBeUsedAsIngredient: _canBeUsedAsIngredient,
                                    isManufactured: _isManufactured,
                                    baseIngredientRequiredPerUnit: double.tryParse(_baseRatioController.text) ?? 1.0,
                                    minStockAlert: double.tryParse(_minAlertController.text) ?? 5.0,
                                    notes: _notesController.text.trim(),
                                    category: _categoryController.text.trim(),
                                    isSplitProduct: _isSplitProduct,
                                    splitFactor: double.tryParse(_splitFactorController.text) ?? 1.0,
                                    subUnitName: _subUnitNameController.text.trim(),
                                    unitSellingPrice: double.tryParse(_unitSellingPriceController.text) ?? 0,
                                    maxCapacity: maxCap > 0 ? maxCap : 100.0,
                                  ));
                                } else {
                                  product.name = _nameController.text.trim();
                                  product.purchasePrice = double.tryParse(_buyPriceController.text) ?? 0;
                                  product.sellingPrice = double.tryParse(_sellPriceController.text) ?? 0;
                                  product.barcode = _barcodeController.text.trim();
                                  product.unit = _selectedUnit;
                                  product.canBeUsedAsIngredient = _canBeUsedAsIngredient;
                                  product.isManufactured = _isManufactured;
                                  product.baseIngredientRequiredPerUnit = double.tryParse(_baseRatioController.text) ?? 1.0;
                                  product.minStockAlert = double.tryParse(_minAlertController.text) ?? 5.0;
                                  product.notes = _notesController.text.trim();
                                  product.category = _categoryController.text.trim();
                                  product.isSplitProduct = _isSplitProduct;
                                  product.splitFactor = double.tryParse(_splitFactorController.text) ?? 1.0;
                                  product.subUnitName = _subUnitNameController.text.trim();
                                  product.unitSellingPrice = double.tryParse(_unitSellingPriceController.text) ?? 0;
                                  product.maxCapacity = maxCap > 0 ? maxCap : 100.0;
                                }
                              });
                              widget.onUpdate();
                              Navigator.pop(ctx);
                              ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('تم حفظ المادة بنجاح!'), backgroundColor: Colors.green));
                            }
                          },
                          icon: const Icon(Icons.save),
                          label: const Text('حفظ المادة', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                        ),
                      ),
                      const SizedBox(height: 20),
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    List<ProductModel> displayedProducts = _filterCategory == 'الكل'
        ? widget.products
        : widget.products.where((p) => p.category == _filterCategory).toList();

    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('إدارة كتالوج المواد والأصناف'),
          backgroundColor: Colors.brown.shade100,
          bottom: PreferredSize(
            preferredSize: const Size.fromHeight(50),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              color: Colors.white,
              child: Row(
                children: [
                  const Text('فرز حسب الصنف: ', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                  const SizedBox(width: 8),
                  Expanded(
                    child: DropdownButton<String>(
                      isExpanded: true,
                      value: _filterCategory,
                      items: ['الكل', 'ألبان وأجبان', 'غذائيات', 'بسكويت'].map((cat) => DropdownMenuItem(value: cat, child: Text(cat, style: const TextStyle(fontSize: 13)))).toList(),
                      onChanged: (v) => setState(() => _filterCategory = v!),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        body: ListView.builder(
          itemCount: displayedProducts.length,
          itemBuilder: (ctx, idx) {
            final p = displayedProducts[idx];
            return Card(
              child: ListTile(
                leading: CircleAvatar(
                  backgroundColor: p.isManufactured ? Colors.teal.shade100 : (p.isSplitProduct ? Colors.brown.shade100 : Colors.amber.shade100),
                  child: Icon(
                    p.isManufactured ? Icons.precision_manufacturing : (p.isSplitProduct ? Icons.call_split : Icons.category),
                    color: p.isManufactured ? Colors.teal : (p.isSplitProduct ? Colors.brown : Colors.amber.shade800),
                    size: 20,
                  ),
                ),
                title: Text('${p.name} [${p.category}]', style: const TextStyle(fontWeight: FontWeight.bold)),
                subtitle: Text(p.isManufactured 
                    ? 'مصنّع | معيار الخام: ${formatDecimal(p.baseIngredientRequiredPerUnit)}'
                    : (p.isSplitProduct
                        ? 'رئيسي (${p.unit}): ${formatNumber(p.sellingPrice)} | مفرق (${p.subUnitName}): ${formatNumber(p.unitSellingPrice)}'
                        : 'التكلفة: ${formatNumber(p.purchasePrice)} | البيع: ${formatNumber(p.sellingPrice)} (${p.unit})')),
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(icon: const Icon(Icons.edit, color: Colors.blue), onPressed: () => _openProductCardSheet(product: p)),
                    if (widget.isAdmin)
                      IconButton(icon: const Icon(Icons.delete, color: Colors.red), onPressed: () {
                        setState(() => widget.products.remove(p));
                        widget.onUpdate();
                      }),
                  ],
                ),
              ),
            );
          },
        ),
        floatingActionButton: FloatingActionButton.extended(
          backgroundColor: Colors.brown,
          onPressed: () => _openProductCardSheet(),
          icon: const Icon(Icons.add, color: Colors.white),
          label: const Text('إضافة مادة جديدة', style: TextStyle(color: Colors.white)),
        ),
      ),
    );
  }
}

// ================= 6. Stock Management =================
class StockManagementWidget extends StatefulWidget {
  final List<ProductModel> products;
  final List<PaymentVoucherModel> vouchers;
  final List<SupplierModel> suppliers;
  final VoidCallback onUpdate;
  final bool isAdmin;

  const StockManagementWidget({super.key, required this.products, required this.vouchers, required this.suppliers, required this.onUpdate, required this.isAdmin});

  @override
  State<StockManagementWidget> createState() => _StockManagementWidgetState();
}

class _StockManagementWidgetState extends State<StockManagementWidget> {
  String _stockFilterCategory = 'الكل';

  void _openSpecificProductCard(ProductModel product) {
    Navigator.push(context, MaterialPageRoute(builder: (c) => ProductCatalogWidget(
      products: widget.products,
      onUpdate: widget.onUpdate,
      isAdmin: widget.isAdmin,
      targetProductToEdit: product,
    )));
  }

  void _splitProductStock(ProductModel product) {
    final TextEditingController splitCountCtrl = TextEditingController(text: '1');
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('تجزئة وتفكيك: ${product.name}'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('الرصيد الحالي: ${formatDecimal(product.stockQuantity)} ${product.unit}'),
            const SizedBox(height: 8),
            Text('كل 1 ${product.unit} يعطي ${product.splitFactor} ${product.subUnitName}'),
            const SizedBox(height: 12),
            TextField(controller: splitCountCtrl, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'عدد الوحدات المراد تفكيكها', border: OutlineInputBorder())),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('إلغاء')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.brown, foregroundColor: Colors.white),
            onPressed: () {
              double countToSplit = double.tryParse(splitCountCtrl.text) ?? 0;
              if (countToSplit > 0 && product.stockQuantity >= countToSplit) {
                setState(() {
                  product.stockQuantity -= countToSplit;
                });
                widget.onUpdate();
                Navigator.pop(ctx);
                ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('تم تفكيك $countToSplit ${product.unit} بنجاح!'), backgroundColor: Colors.green));
              } else {
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('الكمية غير كافية بالمخزن!'), backgroundColor: Colors.red));
              }
            },
            child: const Text('اعتماد التجزئة'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    List<ProductModel> filteredStock = _stockFilterCategory == 'الكل'
        ? widget.products
        : widget.products.where((p) => p.category == _stockFilterCategory).toList();

    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('إدارة المخزن والترتيب'),
          backgroundColor: Colors.orange.shade100,
          bottom: PreferredSize(
            preferredSize: const Size.fromHeight(50),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              color: Colors.white,
              child: Row(
                children: [
                  const Text('ترتيب المخزن حسب الصنف: ', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                  const SizedBox(width: 8),
                  Expanded(
                    child: DropdownButton<String>(
                      isExpanded: true,
                      value: _stockFilterCategory,
                      items: ['الكل', 'ألبان وأجبان', 'غذائيات', 'بسكويت'].map((cat) => DropdownMenuItem(value: cat, child: Text(cat, style: const TextStyle(fontSize: 13)))).toList(),
                      onChanged: (v) => setState(() => _stockFilterCategory = v!),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        body: ListView.builder(
          itemCount: filteredStock.length,
          itemBuilder: (ctx, idx) {
            final p = filteredStock[idx];
            double maxCap = p.maxCapacity > 0 ? p.maxCapacity : 100.0;
            double percentage = (p.stockQuantity / maxCap) * 100;
            if (percentage > 100) percentage = 100;
            if (percentage < 0) percentage = 0;

            bool isCriticalLow = percentage < 10.0 || p.stockQuantity <= p.minStockAlert;
            double fullPacks = p.stockQuantity.floorToDouble();
            double remainingPieces = ((p.stockQuantity - fullPacks) * p.splitFactor).roundToDouble();

            return Card(
              color: isCriticalLow ? Colors.red.shade50 : Colors.white,
              margin: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              child: Padding(
                padding: const EdgeInsets.all(12.0),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Expanded(child: Text('${p.name} [${p.category}]', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16))),
                              if (isCriticalLow)
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                  decoration: BoxDecoration(color: Colors.red, borderRadius: BorderRadius.circular(4)),
                                  child: const Text('أقل من 10% ⚠️', style: TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold)),
                                ),
                            ],
                          ),
                          const SizedBox(height: 4),
                          Text(p.isSplitProduct
                              ? 'الرصيد: ${formatDecimal(fullPacks)} ${p.unit} و ${formatDecimal(remainingPieces)} ${p.subUnitName}'
                              : 'الرصيد الحالي: ${formatDecimal(p.stockQuantity)} ${p.unit}',
                              style: const TextStyle(color: Colors.grey, fontSize: 13)),
                          const SizedBox(height: 8),
                          Row(
                            children: [
                              Expanded(
                                child: ClipRRect(
                                  borderRadius: BorderRadius.circular(4),
                                  child: LinearProgressIndicator(
                                    value: percentage / 100,
                                    backgroundColor: Colors.grey.shade300,
                                    color: isCriticalLow ? Colors.red : Colors.green.shade600,
                                    minHeight: 8,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 10),
                              Text('${percentage.toStringAsFixed(0)}%', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: isCriticalLow ? Colors.red : Colors.black87)),
                            ],
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    IconButton(
                      icon: const Icon(Icons.edit_note, color: Colors.indigo, size: 28),
                      tooltip: 'فتح بطاقة هذه المادة مباشرة',
                      onPressed: () => _openSpecificProductCard(p),
                    ),
                    if (p.isManufactured)
                      IconButton(
                        icon: const Icon(Icons.precision_manufacturing, color: Colors.teal, size: 26),
                        tooltip: 'وحدة التصنيع',
                        onPressed: () {
                          Navigator.push(context, MaterialPageRoute(builder: (c) => Scaffold(
                            appBar: AppBar(title: const Text('وحدة التصنيع والتشغيل'), backgroundColor: Colors.teal),
                            body: AdvancedProductionWidget(products: widget.products, vouchers: widget.vouchers, onUpdate: widget.onUpdate, isAdmin: widget.isAdmin),
                          )));
                        },
                      )
                    else if (p.isSplitProduct)
                      IconButton(
                        icon: const Icon(Icons.call_split, color: Colors.brown, size: 26),
                        tooltip: 'تجزئة وتفكيك',
                        onPressed: () => _splitProductStock(p),
                      ),
                    IconButton(
                      icon: const Icon(Icons.add_circle, color: Colors.green, size: 30),
                      tooltip: 'تعديل سريع للكمية',
                      onPressed: () {
                        final TextEditingController qtyEditCtrl = TextEditingController(text: p.stockQuantity.toString());
                        showDialog(
                          context: context,
                          builder: (ctx) => AlertDialog(
                            title: Text('تعديل مخزون: ${p.name}'),
                            content: TextField(controller: qtyEditCtrl, keyboardType: TextInputType.number, decoration: InputDecoration(labelText: 'الكمية بـ (${p.unit})')),
                            actions: [
                              TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('إلغاء')),
                              ElevatedButton(onPressed: () {
                                setState(() => p.stockQuantity = double.tryParse(qtyEditCtrl.text) ?? p.stockQuantity);
                                widget.onUpdate();
                                Navigator.pop(ctx);
                              }, child: const Text('حفظ')),
                            ],
                          ),
                        );
                      },
                    ),
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}

// ================= 7. Advanced Production Module =================
class AdvancedProductionWidget extends StatefulWidget {
  final List<ProductModel> products;
  final List<PaymentVoucherModel> vouchers;
  final VoidCallback onUpdate;
  final bool isAdmin;

  const AdvancedProductionWidget({super.key, required this.products, required this.vouchers, required this.onUpdate, required this.isAdmin});

  @override
  State<AdvancedProductionWidget> createState() => _AdvancedProductionWidgetState();
}

class _AdvancedProductionWidgetState extends State<AdvancedProductionWidget> {
  ProductModel? _selectedSourceIngredient;
  ProductModel? _selectedTargetProduct;
  final TextEditingController _producedQtyController = TextEditingController(text: '10');
  
  final TextEditingController _unitHeatingCostController = TextEditingController(text: '0');
  final TextEditingController _unitPackagingCostController = TextEditingController(text: '0');
  final TextEditingController _unitOtherCostController = TextEditingController(text: '0');
  
  bool _recordAsExpenseVoucher = true;

  @override
  Widget build(BuildContext context) {
    final ingredientList = widget.products.where((p) => p.canBeUsedAsIngredient).toList();
    final manufacturedList = widget.products.where((p) => p.isManufactured).toList();

    if (ingredientList.isNotEmpty && (_selectedSourceIngredient == null || !ingredientList.contains(_selectedSourceIngredient))) {
      _selectedSourceIngredient = ingredientList.first;
    }
    if (manufacturedList.isNotEmpty && (_selectedTargetProduct == null || !manufacturedList.contains(_selectedTargetProduct))) {
      _selectedTargetProduct = manufacturedList.first;
    }

    double producedQty = double.tryParse(_producedQtyController.text) ?? 0;
    double unitHeating = double.tryParse(_unitHeatingCostController.text) ?? 0;
    double unitPackaging = double.tryParse(_unitPackagingCostController.text) ?? 0;
    double unitOther = double.tryParse(_unitOtherCostController.text) ?? 0;

    double totalOperationalOverhead = (unitHeating + unitPackaging + unitOther) * producedQty;
    double neededIngredientQty = (_selectedTargetProduct != null) ? (producedQty * _selectedTargetProduct!.baseIngredientRequiredPerUnit) : 0;
    double ingredientUnitPrice = (_selectedSourceIngredient != null) ? _selectedSourceIngredient!.purchasePrice : 0;
    double totalRawMaterialCost = neededIngredientQty * ingredientUnitPrice;
    
    double grandBatchCost = totalRawMaterialCost + totalOperationalOverhead;
    double calculatedCostPerUnit = producedQty > 0 ? (grandBatchCost / producedQty) : 0;

    return Directionality(
      textDirection: TextDirection.rtl,
      child: Padding(
        padding: const EdgeInsets.all(12.0),
        child: ListView(
          children: [
            const Text('وحدة التصنيع وحساب التكاليف', style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Colors.teal)),
            const Divider(),
            Row(
              children: [
                Expanded(
                  child: DropdownButtonFormField<ProductModel>(
                    value: _selectedSourceIngredient,
                    style: const TextStyle(fontSize: 13, color: Colors.black87),
                    decoration: const InputDecoration(labelText: 'المادة الأساسية (خام)', border: OutlineInputBorder()),
                    items: ingredientList.map((p) => DropdownMenuItem(value: p, child: Text('${p.name} (${formatDecimal(p.stockQuantity)})', style: const TextStyle(fontSize: 13)))).toList(),
                    onChanged: (v) => setState(() => _selectedSourceIngredient = v),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: DropdownButtonFormField<ProductModel>(
                    value: _selectedTargetProduct,
                    style: const TextStyle(fontSize: 13, color: Colors.black87),
                    decoration: const InputDecoration(labelText: 'المادة المصنعة الناتجة', border: OutlineInputBorder()),
                    items: manufacturedList.map((p) => DropdownMenuItem(value: p, child: Text(p.name, style: const TextStyle(fontSize: 13)))).toList(),
                    onChanged: (v) => setState(() => _selectedTargetProduct = v),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            TextField(controller: _producedQtyController, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'الكمية المنتجة الناتجة', border: OutlineInputBorder()), onChanged: (v) => setState(() {})),
            const SizedBox(height: 12),
            const Text('تكلفة الوحدة الواحدة:', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.brown, fontSize: 13)),
            const SizedBox(height: 6),
            Row(
              children: [
                Expanded(child: TextField(controller: _unitHeatingCostController, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'غاز/كهرباء للوحدة', border: OutlineInputBorder(), isDense: true), onChanged: (v) => setState(() {}))),
                const SizedBox(width: 6),
                Expanded(child: TextField(controller: _unitPackagingCostController, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'علبة/غلاف للوحدة', border: OutlineInputBorder(), isDense: true), onChanged: (v) => setState(() {}))),
                const SizedBox(width: 6),
                Expanded(child: TextField(controller: _unitOtherCostController, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'أخرى للوحدة', border: OutlineInputBorder(), isDense: true), onChanged: (v) => setState(() {}))),
              ],
            ),
            const SizedBox(height: 10),
            CheckboxListTile(
              title: const Text('تسجيل المصاريف التشغيلية الإجمالية تلقائياً'),
              value: _recordAsExpenseVoucher,
              onChanged: (v) => setState(() => _recordAsExpenseVoucher = v ?? true),
            ),
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(color: Colors.teal.shade50, border: Border.all(color: Colors.teal), borderRadius: BorderRadius.circular(8)),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('• الكمية المطلوبة من الخام: ${formatDecimal(neededIngredientQty)}'),
                  Text('• تكلفة المواد الخام الإجمالية: ${formatNumber(totalRawMaterialCost)} ل.س'),
                  Text('• إجمالي مصاريف التشغيل: ${formatNumber(totalOperationalOverhead)} ل.س'),
                  const Divider(),
                  Text('• تكلفة الوحدة الفعلية النهائية: ${formatNumber(calculatedCostPerUnit)} ل.س', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.teal)),
                ],
              ),
            ),
            const SizedBox(height: 15),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: Colors.teal.shade700, foregroundColor: Colors.white),
              onPressed: () {
                if (_selectedSourceIngredient == null || _selectedTargetProduct == null || producedQty <= 0) return;
                if (_selectedSourceIngredient!.stockQuantity < neededIngredientQty) {
                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('الكمية الأساسية الخام غير كافية بالمخزن!'), backgroundColor: Colors.red));
                  return;
                }
                setState(() {
                  _selectedSourceIngredient!.stockQuantity -= neededIngredientQty;
                  _selectedTargetProduct!.stockQuantity += producedQty;
                  _selectedTargetProduct!.purchasePrice = calculatedCostPerUnit;
                  
                  if (_recordAsExpenseVoucher && totalOperationalOverhead > 0) {
                    widget.vouchers.add(PaymentVoucherModel(
                      title: 'تصنيع ${_selectedTargetProduct!.name} ($producedQty وحدة)',
                      amount: totalOperationalOverhead,
                      details: 'مصاريف تشغيل',
                      date: DateTime.now(),
                    ));
                  }
                });
                widget.onUpdate();
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('تم إتمام التصنيع وحساب التكاليف بنجاح!'), backgroundColor: Colors.green));
              },
              child: const Text('اعتماد التصنيع وتحديث المخزون'),
            )
          ],
        ),
      ),
    );
  }
}

// ================= 8. Invoices Manager =================
class InvoicesManagerWidget extends StatefulWidget {
  final List<InvoiceModel> invoices;
  final InvoiceType type;
  final Function(InvoiceModel) onDelete;
  final bool isAdmin;

  const InvoicesManagerWidget({super.key, required this.invoices, required this.type, required this.onDelete, required this.isAdmin});

  @override
  State<InvoicesManagerWidget> createState() => _InvoicesManagerWidgetState();
}

class _InvoicesManagerWidgetState extends State<InvoicesManagerWidget> {
  void _confirmDelete(InvoiceModel invoice) {
    if (!widget.isAdmin && !AppSettings.subAccountCanDeleteInvoice) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('الحساب الفرعي لا يمتلك صلاحية الحذف'), backgroundColor: Colors.red));
      return;
    }
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('تأكيد الحذف'),
        content: const Text('هل أنت متأكد من حذف الفاتورة؟ سيتم عكس تأثيرها على المخزن.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('إلغاء')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red, foregroundColor: Colors.white),
            onPressed: () {
              widget.onDelete(invoice);
              Navigator.pop(ctx);
              setState(() {});
              ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('تم حذف الفاتورة بنجاح'), backgroundColor: Colors.green));
            },
            child: const Text('حذف'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    bool isSales = widget.type == InvoiceType.sales;
    List<InvoiceModel> filtered = widget.invoices.where((i) => i.type == widget.type).toList();

    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        appBar: AppBar(title: Text(isSales ? 'إدارة فواتير المبيع' : 'إدارة فواتير الشراء'), backgroundColor: isSales ? Colors.green.shade700 : Colors.blue.shade700, foregroundColor: Colors.white),
        body: filtered.isEmpty
            ? Center(child: Text(isSales ? 'لا توجد فواتير مبيع مسجلة' : 'لا توجد فواتير شراء مسجلة', style: const TextStyle(color: Colors.grey, fontSize: 16)))
            : ListView.builder(
                padding: const EdgeInsets.all(10),
                itemCount: filtered.length,
                itemBuilder: (ctx, idx) {
                  final inv = filtered.reversed.toList()[idx];
                  String timeStr = "${inv.date.year}/${inv.date.month}/${inv.date.day} - ${inv.date.hour.toString().padLeft(2, '0')}:${inv.date.minute.toString().padLeft(2, '0')}";
                  return Card(
                    child: ExpansionTile(
                      title: Text('${inv.partyName} - ${formatNumber(inv.totalAmount)} ل.س', style: const TextStyle(fontWeight: FontWeight.bold)),
                      subtitle: Text('التاريخ: $timeStr | الحالة: ${inv.isDebt ? "آجل (دين)" : "نقدي"}'),
                      trailing: IconButton(icon: const Icon(Icons.delete, color: Colors.red), onPressed: () => _confirmDelete(inv)),
                      children: [
                        const Divider(),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text('تفاصيل المواد في الفاتورة:', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.brown)),
                              const SizedBox(height: 5),
                              ...inv.items.map((item) => Padding(
                                    padding: const EdgeInsets.symmetric(vertical: 2.0),
                                    child: Row(
                                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                      children: [
                                        Text('• ${item.product.name} (${item.unitLabelUsed})'),
                                        Text('${formatDecimal(item.quantity)} × ${formatNumber(item.priceUsed)} = ${formatNumber(item.total)} ل.س'),
                                      ],
                                    ),
                                  )),
                              const Divider(),
                              if (isSales) Text('إجمالي الربح من الفاتورة: ${formatNumber(inv.totalProfit)} ل.س', style: const TextStyle(color: Colors.green, fontWeight: FontWeight.bold)),
                            ],
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),
      ),
    );
  }
}

// ================= 9. Invoice Builder =================
class InvoiceBuilderWidget extends StatefulWidget {
  final InvoiceType type;
  final List<ProductModel> products;
  final List<SupplierModel> suppliers;
  final Function(InvoiceModel, bool) onSubmit;

  const InvoiceBuilderWidget({super.key, required this.type, required this.products, required this.suppliers, required this.onSubmit});

  @override
  State<InvoiceBuilderWidget> createState() => _InvoiceBuilderWidgetState();
}

class _InvoiceBuilderWidgetState extends State<InvoiceBuilderWidget> {
  final List<InvoiceItem> _items = [];
  final TextEditingController _partyController = TextEditingController();
  final TextEditingController _qtyOrPriceController = TextEditingController(text: '1');
  final TextEditingController _discountController = TextEditingController(text: '0');
  final TextEditingController _searchProductController = TextEditingController();

  ProductModel? _selectedProduct;
  bool _isDebt = false;
  bool _sellAsSubUnit = false;
  bool _isSaleByPriceInsteadOfWeight = false;

  @override
  void initState() {
    super.initState();
    if (widget.products.isNotEmpty) {
      _selectedProduct = widget.products.first;
    }
  }

  Future<void> _scanBarcodeForProduct() async {
    final scannedCode = await Navigator.push<String>(context, MaterialPageRoute(builder: (context) => const BarcodeScannerScreen()));
    if (scannedCode != null && scannedCode.isNotEmpty) {
      try {
        ProductModel found = widget.products.firstWhere((p) => p.barcode == scannedCode);
        setState(() {
          _selectedProduct = found;
          _sellAsSubUnit = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('تم العثور على المادة: ${found.name}'), backgroundColor: Colors.green));
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('الباركود ($scannedCode) غير مسجل!'), backgroundColor: Colors.red));
      }
    }
  }

  void _addItem() {
    if (_selectedProduct == null) return;
    bool isSales = widget.type == InvoiceType.sales;

    double baseUnitPrice = isSales
        ? (_sellAsSubUnit ? _selectedProduct!.unitSellingPrice : _selectedProduct!.sellingPrice)
        : _selectedProduct!.purchasePrice;

    if (baseUnitPrice <= 0) return;

    double inputVal = double.tryParse(_qtyOrPriceController.text.trim()) ?? 0;
    if (inputVal <= 0) return;

    double finalQtyCalculated = inputVal;
    double finalPriceUsed = baseUnitPrice;
    String labelUsed = _selectedProduct!.unit;

    if (isSales && _isSaleByPriceInsteadOfWeight) {
      finalPriceUsed = baseUnitPrice;
      finalQtyCalculated = inputVal / baseUnitPrice; 
      labelUsed = '${_selectedProduct!.unit} (حسب السعر المدفوع)';
    } else if (_sellAsSubUnit && _selectedProduct!.isSplitProduct && isSales) {
      finalQtyCalculated = inputVal / _selectedProduct!.splitFactor;
      finalPriceUsed = _selectedProduct!.unitSellingPrice;
      labelUsed = '${_selectedProduct!.subUnitName} (مفرق)';
    } else {
      labelUsed = _selectedProduct!.unit;
    }

    setState(() {
      _items.add(InvoiceItem(
        product: _selectedProduct!,
        quantity: finalQtyCalculated,
        priceUsed: finalPriceUsed,
        unitLabelUsed: labelUsed,
      ));
      _qtyOrPriceController.text = '1';
    });
  }

  void _saveInvoice() {
    if (_items.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('يرجى إضافة مواد للفاتورة أولاً')));
      return;
    }

    double subTotal = _items.fold(0, (sum, i) => sum + i.total);
    double discountOrExtra = double.tryParse(_discountController.text) ?? 0;
    double totalAmount = subTotal + discountOrExtra;
    double profit = widget.type == InvoiceType.sales ? _items.fold(0, (sum, i) => sum + i.profit) : 0;

    String defaultName = widget.type == InvoiceType.sales ? 'زبون عام' : 'مورد عام';
    String party = _partyController.text.trim().isEmpty ? defaultName : _partyController.text.trim();

    InvoiceModel invoice = InvoiceModel(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      partyName: party,
      items: List.from(_items),
      subTotal: subTotal,
      discountOrExtra: discountOrExtra,
      totalAmount: totalAmount,
      totalProfit: profit,
      date: DateTime.now(),
      type: widget.type,
      isDebt: _isDebt,
    );

    widget.onSubmit(invoice, _isDebt);
    setState(() {
      _items.clear();
      _partyController.clear();
      _discountController.text = '0';
      _isDebt = false;
    });

    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('تم حفظ الفاتورة بنجاح وتزامنت سحابياً!'), backgroundColor: Colors.green));
  }

  @override
  Widget build(BuildContext context) {
    bool isSales = widget.type == InvoiceType.sales;
    if (widget.products.isNotEmpty && (_selectedProduct == null || !widget.products.contains(_selectedProduct))) {
      _selectedProduct = widget.products.first;
    }

    String query = _searchProductController.text.trim().toLowerCase();
    List<ProductModel> filteredProducts = query.isEmpty
        ? widget.products
        : widget.products.where((p) => p.name.toLowerCase().contains(query) || p.barcode.contains(query)).toList();

    double subTotal = _items.fold(0, (sum, i) => sum + i.total);
    double discount = double.tryParse(_discountController.text) ?? 0;
    double finalTotal = subTotal + discount;
    double totalProfit = isSales ? _items.fold(0, (sum, i) => sum + i.profit) : 0;

    return Directionality(
      textDirection: TextDirection.rtl,
      child: Padding(
        padding: const EdgeInsets.all(12.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(isSales ? 'فاتورة مبيع جديدة' : 'فاتورة شراء جديدة', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: isSales ? Colors.green.shade800 : Colors.blue.shade800)),
                IconButton(onPressed: _scanBarcodeForProduct, icon: const Icon(Icons.qr_code_scanner, color: Colors.indigo, size: 28), tooltip: 'مسح باركود'),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(child: TextField(controller: _partyController, decoration: InputDecoration(labelText: isSales ? 'اسم الزبون' : 'اسم المورد', border: const OutlineInputBorder(), isDense: true))),
                if (!isSales && widget.suppliers.isNotEmpty)
                  PopupMenuButton<String>(
                    icon: const Icon(Icons.arrow_drop_down_circle, color: Colors.blue, size: 28),
                    onSelected: (name) => setState(() => _partyController.text = name),
                    itemBuilder: (context) => widget.suppliers.map((s) => PopupMenuItem(value: s.name, child: Text(s.name))).toList(),
                  )
              ],
            ),
            const SizedBox(height: 10),
            TextField(
              controller: _searchProductController,
              decoration: InputDecoration(
                labelText: 'بحث عن مادة...',
                prefixIcon: const Icon(Icons.search, size: 20),
                border: const OutlineInputBorder(),
                isDense: true,
                suffixIcon: _searchProductController.text.isNotEmpty
                    ? IconButton(icon: const Icon(Icons.clear, size: 18), onPressed: () => setState(() => _searchProductController.clear()))
                    : null,
              ),
              onChanged: (v) => setState(() {}),
            ),
            const SizedBox(height: 8),
            DropdownButtonFormField<ProductModel>(
              value: filteredProducts.contains(_selectedProduct) ? _selectedProduct : (filteredProducts.isNotEmpty ? filteredProducts.first : null),
              style: const TextStyle(fontSize: 13, color: Colors.black87),
              decoration: const InputDecoration(labelText: 'اختر المادة', border: OutlineInputBorder(), isDense: true),
              items: filteredProducts.map((p) => DropdownMenuItem(value: p, child: Text('${p.name} (${formatNumber(isSales ? p.sellingPrice : p.purchasePrice)})', style: const TextStyle(fontSize: 13)))).toList(),
              onChanged: (v) => setState(() {
                _selectedProduct = v;
                _sellAsSubUnit = false;
              }),
            ),
            if (_selectedProduct != null && isSales) ...[
              const SizedBox(height: 6),
              Row(
                children: [
                  ChoiceChip(
                    label: Text('بالوزن / الكمية (${_selectedProduct!.unit})'),
                    selected: !_isSaleByPriceInsteadOfWeight && !_sellAsSubUnit,
                    selectedColor: Colors.amber.shade200,
                    onSelected: (v) => setState(() { _isSaleByPriceInsteadOfWeight = false; _sellAsSubUnit = false; }),
                  ),
                  const SizedBox(width: 6),
                  ChoiceChip(
                    label: const Text('بمبلغ مالي'),
                    selected: _isSaleByPriceInsteadOfWeight,
                    selectedColor: Colors.green.shade200,
                    onSelected: (v) => setState(() { _isSaleByPriceInsteadOfWeight = true; _sellAsSubUnit = false; }),
                  ),
                  if (_selectedProduct!.isSplitProduct) ...[
                    const SizedBox(width: 6),
                    ChoiceChip(
                      label: Text('مفرق (${_selectedProduct!.subUnitName})'),
                      selected: _sellAsSubUnit,
                      selectedColor: Colors.orange.shade200,
                      onSelected: (v) => setState(() { _sellAsSubUnit = true; _isSaleByPriceInsteadOfWeight = false; }),
                    ),
                  ],
                ],
              ),
            ],
            const SizedBox(height: 6),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _qtyOrPriceController,
                    keyboardType: TextInputType.number,
                    decoration: InputDecoration(
                      labelText: _isSaleByPriceInsteadOfWeight ? 'أدخل المبلغ الإجمالي (ل.س)' : (_sellAsSubUnit ? 'عدد الـ ${_selectedProduct?.subUnitName} (مفرق)' : 'الكمية (${_selectedProduct?.unit})'),
                      border: const OutlineInputBorder(),
                      isDense: true,
                    ),
                  ),
                ),
                const SizedBox(width: 6),
                ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(backgroundColor: isSales ? Colors.green : Colors.blue, foregroundColor: Colors.white),
                  onPressed: _addItem,
                  icon: const Icon(Icons.add),
                  label: const Text('إضافة'),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Expanded(
              child: Container(
                decoration: BoxDecoration(border: Border.all(color: Colors.grey.shade300), borderRadius: BorderRadius.circular(8)),
                child: _items.isEmpty
                    ? const Center(child: Text('لم تقم بإضافة مواد للفاتورة بعد'))
                    : ListView.builder(
                        itemCount: _items.length,
                        itemBuilder: (ctx, idx) {
                          final item = _items[idx];
                          return ListTile(
                            title: Text('${item.product.name} (${item.unitLabelUsed})'),
                            subtitle: Text('الكمية المخسومة: ${formatDecimal(item.quantity)} × السعر: ${formatNumber(item.priceUsed)}'),
                            trailing: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text('${formatNumber(item.total)} ل.س', style: const TextStyle(fontWeight: FontWeight.bold)),
                                IconButton(icon: const Icon(Icons.delete, color: Colors.red, size: 18), onPressed: () => setState(() => _items.removeAt(idx))),
                              ],
                            ),
                          );
                        },
                      ),
              ),
            ),
            const SizedBox(height: 6),
            Row(
              children: [
                Expanded(child: TextField(controller: _discountController, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'خصم أو إضافي', border: OutlineInputBorder(), isDense: true), onChanged: (v) => setState(() {}))),
                const SizedBox(width: 10),
                Text('الإجمالي: ${formatNumber(finalTotal)} ل.س', style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
              ],
            ),
            if (isSales) ...[
              const SizedBox(height: 4),
              Text('إجمالي الربح التقديري للفاتورة: ${formatNumber(totalProfit)} ل.س', style: const TextStyle(color: Colors.green, fontWeight: FontWeight.bold, fontSize: 13)),
            ],
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(backgroundColor: !_isDebt ? Colors.amber.shade800 : Colors.grey.shade200, foregroundColor: !_isDebt ? Colors.white : Colors.black87),
                    onPressed: () => setState(() => _isDebt = false),
                    icon: const Icon(Icons.money, size: 18),
                    label: const Text('نقدي (كاش)'),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(backgroundColor: _isDebt ? Colors.deepOrange.shade700 : Colors.grey.shade200, foregroundColor: _isDebt ? Colors.white : Colors.black87),
                    onPressed: () => setState(() => _isDebt = true),
                    icon: const Icon(Icons.book, size: 18),
                    label: const Text('آجل (دين)'),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                style: ElevatedButton.styleFrom(backgroundColor: isSales ? Colors.green.shade700 : Colors.blue.shade700, foregroundColor: Colors.white, minimumSize: const Size.fromHeight(45)),
                onPressed: _saveInvoice,
                icon: const Icon(Icons.cloud_upload, size: 18),
                label: const Text('حفظ الفاتورة ومزامنتها سحابياً', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
              ),
            )
          ],
        ),
      ),
    );
  }
}

// ================= 10. Suppliers Widget =================
class SuppliersWidget extends StatefulWidget {
  final List<SupplierModel> suppliers;
  final List<InvoiceModel> invoices;
  final VoidCallback onUpdate;
  final bool isAdmin;

  const SuppliersWidget({super.key, required this.suppliers, required this.invoices, required this.onUpdate, required this.isAdmin});

  @override
  State<SuppliersWidget> createState() => _SuppliersWidgetState();
}

class _SuppliersWidgetState extends State<SuppliersWidget> {
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _phoneController = TextEditingController();
  final TextEditingController _catController = TextEditingController();

  void _showSupplierCardDialog({SupplierModel? supplier}) {
    if (supplier != null) {
      _nameController.text = supplier.name;
      _phoneController.text = supplier.phone;
      _catController.text = supplier.category;
    } else {
      _nameController.clear();
      _phoneController.clear();
      _catController.clear();
    }
    showDialog(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          title: Text(supplier == null ? 'إضافة بطاقة مورد جديدة' : 'بطاقة تفاصيل المورد'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(controller: _nameController, decoration: const InputDecoration(labelText: 'اسم المورد / الشركة', border: OutlineInputBorder())),
              const SizedBox(height: 10),
              TextField(controller: _phoneController, keyboardType: TextInputType.phone, decoration: const InputDecoration(labelText: 'رقم الهاتف', border: OutlineInputBorder())),
              const SizedBox(height: 10),
              TextField(controller: _catController, decoration: const InputDecoration(labelText: 'نوع التوريد (مثال: حليب خام...)', border: OutlineInputBorder())),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('إلغاء')),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: Colors.indigo, foregroundColor: Colors.white),
              onPressed: () {
                if (_nameController.text.isNotEmpty) {
                  setState(() {
                    if (supplier == null) {
                      widget.suppliers.add(SupplierModel(id: DateTime.now().toString(), name: _nameController.text.trim(), phone: _phoneController.text.trim(), category: _catController.text.trim()));
                    } else {
                      supplier.name = _nameController.text.trim();
                      supplier.phone = _phoneController.text.trim();
                      supplier.category = _catController.text.trim();
                    }
                  });
                  widget.onUpdate();
                  Navigator.pop(ctx);
                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('تم حفظ بيانات المورد بنجاح!'), backgroundColor: Colors.green));
                }
              },
              child: const Text('حفظ بطاقة المورد'),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        appBar: AppBar(title: const Text('بطاقات الموردين ومعلوماتهم'), backgroundColor: Colors.indigo.shade100),
        body: ListView.builder(
          itemCount: widget.suppliers.length,
          itemBuilder: (ctx, idx) {
            final sup = widget.suppliers[idx];
            return Card(
              margin: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              child: Padding(
                padding: const EdgeInsets.all(12.0),
                child: Row(
                  children: [
                    const CircleAvatar(backgroundColor: Colors.indigo, child: Icon(Icons.local_shipping, color: Colors.white)),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(sup.name, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                          const SizedBox(height: 4),
                          Text('نوع التوريد: ${sup.category}', style: const TextStyle(color: Colors.grey, fontSize: 13)),
                          Text('رقم الهاتف: ${sup.phone.isEmpty ? "غير محدد" : sup.phone}', style: const TextStyle(color: Colors.grey, fontSize: 13)),
                        ],
                      ),
                    ),
                    IconButton(icon: const Icon(Icons.edit, color: Colors.blue), tooltip: 'تعديل بطاقة المورد', onPressed: () => _showSupplierCardDialog(supplier: sup)),
                    if (widget.isAdmin)
                      IconButton(icon: const Icon(Icons.delete, color: Colors.red), tooltip: 'حذف المورد', onPressed: () {
                        setState(() => widget.suppliers.removeAt(idx));
                        widget.onUpdate();
                      }),
                  ],
                ),
              ),
            );
          },
        ),
        floatingActionButton: FloatingActionButton.extended(
          backgroundColor: Colors.indigo,
          onPressed: () => _showSupplierCardDialog(),
          icon: const Icon(Icons.add),
          label: const Text('إضافة مورد جديد', style: TextStyle(color: Colors.white)),
        ),
      ),
    );
  }
}

// ================= 11. Payment Vouchers / Expenses =================
class PaymentVouchersWidget extends StatefulWidget {
  final List<PaymentVoucherModel> vouchers;
  final VoidCallback onUpdate;
  final bool isAdmin;

  const PaymentVouchersWidget({super.key, required this.vouchers, required this.onUpdate, required this.isAdmin});

  @override
  State<PaymentVouchersWidget> createState() => _PaymentVouchersWidgetState();
}

class _PaymentVouchersWidgetState extends State<PaymentVouchersWidget> {
  final TextEditingController _titleController = TextEditingController();
  final TextEditingController _amountController = TextEditingController();
  final TextEditingController _detailsController = TextEditingController();

  void _showAddDialog() {
    _titleController.clear();
    _amountController.clear();
    _detailsController.clear();
    showDialog(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          title: const Text('تسجيل مصروف'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(controller: _titleController, decoration: const InputDecoration(labelText: 'نوع المصروف')),
              TextField(controller: _amountController, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'المبلغ')),
              TextField(controller: _detailsController, decoration: const InputDecoration(labelText: 'ملاحظات')),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('إلغاء')),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: Colors.red, foregroundColor: Colors.white),
              onPressed: () {
                double amt = double.tryParse(_amountController.text) ?? 0;
                if (_titleController.text.isNotEmpty && amt > 0) {
                  setState(() => widget.vouchers.add(PaymentVoucherModel(title: _titleController.text.trim(), amount: amt, details: _detailsController.text.trim(), date: DateTime.now())));
                  widget.onUpdate();
                  Navigator.pop(ctx);
                }
              },
              child: const Text('حفظ'),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    double totalExpenses = widget.vouchers.fold(0, (sum, v) => sum + v.amount);
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        appBar: AppBar(title: Text('المصاريف (${formatNumber(totalExpenses)} ل.س)'), backgroundColor: Colors.red.shade100),
        body: ListView.builder(
          itemCount: widget.vouchers.length,
          itemBuilder: (ctx, idx) {
            final v = widget.vouchers[idx];
            return Card(
              child: ListTile(
                title: Text(v.title, style: const TextStyle(fontWeight: FontWeight.bold)),
                subtitle: Text(v.details),
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text('${formatNumber(v.amount)} ل.س', style: const TextStyle(color: Colors.red, fontWeight: FontWeight.bold)),
                    if (widget.isAdmin)
                      IconButton(icon: const Icon(Icons.delete, color: Colors.grey), onPressed: () {
                        setState(() => widget.vouchers.removeAt(idx));
                        widget.onUpdate();
                      }),
                  ],
                ),
              ),
            );
          },
        ),
        floatingActionButton: FloatingActionButton.extended(
          backgroundColor: Colors.red.shade700,
          onPressed: _showAddDialog,
          label: const Text('إضافة مصروف', style: TextStyle(color: Colors.white)),
        ),
      ),
    );
  }
}

// ================= 12. Debts / Credit Tab =================
class DebtsWidget extends StatefulWidget {
  final List<InvoiceModel> invoices;
  final List<DebtPaymentModel> debtPayments;
  final Function(DebtPaymentModel) onAddPayment;

  const DebtsWidget({super.key, required this.invoices, required this.debtPayments, required this.onAddPayment});

  @override
  State<DebtsWidget> createState() => _DebtsWidgetState();
}

class _DebtsWidgetState extends State<DebtsWidget> {
  final TextEditingController _payController = TextEditingController();

  void _showPayDialog(String partyName, double currentBalance, bool isCustomer) {
    _payController.clear();
    showDialog(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          title: Text(isCustomer ? 'سداد من الزبون: $partyName' : 'تسديد للمورد: $partyName'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('المتبقي: ${formatNumber(currentBalance)} ل.س'),
              TextField(controller: _payController, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'المبلغ المدفوع')),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('إلغاء')),
            ElevatedButton(
              onPressed: () {
                double pay = double.tryParse(_payController.text) ?? 0;
                if (pay > 0) {
                  widget.onAddPayment(DebtPaymentModel(partyName: partyName, amountPaid: pay, date: DateTime.now(), isCustomer: isCustomer));
                  Navigator.pop(ctx);
                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('تم تسجيل السداد بنجاح!'), backgroundColor: Colors.green));
                }
              },
              child: const Text('حفظ'),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    Map<String, double> customerDebts = {};
    for (var inv in widget.invoices.where((i) => i.type == InvoiceType.sales && i.isDebt)) {
      customerDebts[inv.partyName] = (customerDebts[inv.partyName] ?? 0) + inv.totalAmount;
    }
    for (var pay in widget.debtPayments.where((p) => p.isCustomer)) {
      if (customerDebts.containsKey(pay.partyName)) {
        customerDebts[pay.partyName] = customerDebts[pay.partyName]! - pay.amountPaid;
      }
    }

    Map<String, double> supplierDebts = {};
    for (var inv in widget.invoices.where((i) => i.type == InvoiceType.purchase && i.isDebt)) {
      supplierDebts[inv.partyName] = (supplierDebts[inv.partyName] ?? 0) + inv.totalAmount;
    }
    for (var pay in widget.debtPayments.where((p) => !p.isCustomer)) {
      if (supplierDebts.containsKey(pay.partyName)) {
        supplierDebts[pay.partyName] = supplierDebts[pay.partyName]! - pay.amountPaid;
      }
    }

    double totalCust = customerDebts.values.fold(0, (s, v) => s + (v > 0 ? v : 0));
    double totalSupp = supplierDebts.values.fold(0, (s, v) => s + (v > 0 ? v : 0));

    return Directionality(
      textDirection: TextDirection.rtl,
      child: DefaultTabController(
        length: 2,
        child: Scaffold(
          appBar: AppBar(bottom: const TabBar(tabs: [Tab(text: 'ديون الزبائن'), Tab(text: 'ديون الموردين')]), automaticallyImplyLeading: false),
          body: Column(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                color: Colors.amber.shade50,
                child: Row(
                  children: [
                    Expanded(child: Card(child: Padding(padding: const EdgeInsets.all(8), child: Text('لنا: ${formatNumber(totalCust)} ل.س', style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.green))))),
                    Expanded(child: Card(child: Padding(padding: const EdgeInsets.all(8), child: Text('علينا: ${formatNumber(totalSupp)} ل.س', style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.red))))),
                  ],
                ),
              ),
              Expanded(
                child: TabBarView(
                  children: [
                    ListView(
                      children: customerDebts.entries.map((e) {
                        if (e.value <= 0) return const SizedBox.shrink();
                        return Card(
                          child: ListTile(
                            title: Text(e.key),
                            subtitle: Text('المتبقي: ${formatNumber(e.value)} ل.س'),
                            trailing: ElevatedButton(onPressed: () => _showPayDialog(e.key, e.value, true), child: const Text('سداد')),
                          ),
                        );
                      }).toList(),
                    ),
                    ListView(
                      children: supplierDebts.entries.map((e) {
                        if (e.value <= 0) return const SizedBox.shrink();
                        return Card(
                          child: ListTile(
                            title: Text(e.key),
                            subtitle: Text('المستحق: ${formatNumber(e.value)} ل.س'),
                            trailing: ElevatedButton(onPressed: () => _showPayDialog(e.key, e.value, false), child: const Text('تسديد')),
                          ),
                        );
                      }).toList(),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ================= 13. Reports, Cloud Stream Sync & Material Movement =================
class ReportsAndBackupWidget extends StatefulWidget {
  final List<ProductModel> products;
  final List<SupplierModel> suppliers;
  final List<InvoiceModel> invoices;
  final List<PaymentVoucherModel> vouchers;
  final List<DebtPaymentModel> debtPayments;
  final VoidCallback onUpdate;
  final Function(InvoiceModel) onDeleteInvoice;
  final bool isAdmin;

  const ReportsAndBackupWidget({
    super.key,
    required this.products,
    required this.suppliers,
    required this.invoices,
    required this.vouchers,
    required this.debtPayments,
    required this.onUpdate,
    required this.onDeleteInvoice,
    required this.isAdmin,
  });

  @override
  State<ReportsAndBackupWidget> createState() => _ReportsAndBackupWidgetState();
}

class _ReportsAndBackupWidgetState extends State<ReportsAndBackupWidget> {
  bool _onlyToday = true;

  void _exportBackup() {
    Map<String, dynamic> comprehensiveBackup = {
      'version': '2.0',
      'app_name': 'Family Dairy Cloud Database',
      'date': DateTime.now().toIso8601String(),
      'products': widget.products.map((p) => p.toJson()).toList(),
      'suppliers': widget.suppliers.map((s) => s.toJson()).toList(),
      'invoices': widget.invoices.map((i) => i.toJson()).toList(),
      'vouchers': widget.vouchers.map((v) => v.toJson()).toList(),
      'debtPayments': widget.debtPayments.map((d) => d.toJson()).toList(),
    };

    String jsonString = jsonEncode(comprehensiveBackup);
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('النسخ الاحتياطي الشامل (.familydairy)'),
        content: SizedBox(
          width: 350,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text('يشمل هذا النسخ كافة الفواتير، المواد، الموردين وحركات المخزن:', style: TextStyle(fontSize: 12, color: Colors.grey)),
                const SizedBox(height: 10),
                SelectableText(jsonString, style: const TextStyle(fontSize: 10)),
              ],
            ),
          ),
        ),
        actions: [ElevatedButton(onPressed: () => Navigator.pop(ctx), child: const Text('تم'))],
      ),
    );
  }

  void _importBackupDialog() {
    final TextEditingController importController = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('استعادة البيانات الكاملة'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('ألصق نص النسخ الاحتياطي هنا:', style: TextStyle(fontSize: 12)),
            const SizedBox(height: 10),
            TextField(controller: importController, maxLines: 5, decoration: const InputDecoration(border: OutlineInputBorder())),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('إلغاء')),
          ElevatedButton(
            onPressed: () {
              try {
                Map<String, dynamic> data = jsonDecode(importController.text);
                if (data.containsKey('products') && data.containsKey('invoices')) {
                  setState(() {
                    widget.products.clear();
                    for (var p in data['products']) {
                      widget.products.add(ProductModel.fromJson(p));
                    }
                    widget.suppliers.clear();
                    if (data['suppliers'] != null) {
                      for (var s in data['suppliers']) {
                        widget.suppliers.add(SupplierModel.fromJson(s));
                      }
                    }
                    widget.vouchers.clear();
                    if (data['vouchers'] != null) {
                      for (var v in data['vouchers']) {
                        widget.vouchers.add(PaymentVoucherModel.fromJson(v));
                      }
                    }
                    widget.debtPayments.clear();
                    if (data['debtPayments'] != null) {
                      for (var d in data['debtPayments']) {
                        widget.debtPayments.add(DebtPaymentModel.fromJson(d));
                      }
                    }
                  });
                  widget.onUpdate();
                  Navigator.pop(ctx);
                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('تمت استعادة كافة البيانات بنجاح!'), backgroundColor: Colors.green));
                }
              } catch (e) {
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('الملف غير صالح!'), backgroundColor: Colors.red));
              }
            },
            child: const Text('استعادة وتثبيت'),
          ),
        ],
      ),
    );
  }

  Future<void> _generatePdfReport(List<InvoiceModel> filteredInvoices, List<PaymentVoucherModel> filteredVouchers) async {
    final pdf = pw.Document();
    double sales = filteredInvoices.where((i) => i.type == InvoiceType.sales).fold(0, (s, i) => s + i.totalAmount);
    double salesProfit = filteredInvoices.where((i) => i.type == InvoiceType.sales).fold(0, (s, i) => s + i.totalProfit);
    double expenses = filteredVouchers.fold(0, (s, v) => s + v.amount);
    double netProfit = salesProfit - expenses;

    pdf.addPage(
      pw.Page(
        build: (pw.Context context) {
          return pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Center(child: pw.Text('Family Dairy Cloud Financial Report', style: pw.TextStyle(fontSize: 18, fontWeight: pw.FontWeight.bold))),
              pw.SizedBox(height: 20),
              pw.Table(
                border: pw.TableBorder.all(width: 0.5),
                children: [
                  pw.TableRow(children: [pw.Padding(padding: const pw.EdgeInsets.all(8), child: pw.Text('Metric')), pw.Padding(padding: const pw.EdgeInsets.all(8), child: pw.Text('Amount'))]),
                  pw.TableRow(children: [pw.Padding(padding: const pw.EdgeInsets.all(8), child: pw.Text('Total Sales')), pw.Padding(padding: const pw.EdgeInsets.all(8), child: pw.Text('$sales'))]),
                  pw.TableRow(children: [pw.Padding(padding: const pw.EdgeInsets.all(8), child: pw.Text('Sales Gross Profit')), pw.Padding(padding: const pw.EdgeInsets.all(8), child: pw.Text('$salesProfit'))]),
                  pw.TableRow(children: [pw.Padding(padding: const pw.EdgeInsets.all(8), child: pw.Text('Expenses')), pw.Padding(padding: const pw.EdgeInsets.all(8), child: pw.Text('$expenses'))]),
                  pw.TableRow(children: [pw.Padding(padding: const pw.EdgeInsets.all(8), child: pw.Text('Net Profit')), pw.Padding(padding: const pw.EdgeInsets.all(8), child: pw.Text('$netProfit'))]),
                ],
              ),
            ],
          );
        },
      ),
    );
    await Printing.layoutPdf(onLayout: (format) async => pdf.save());
  }

  @override
  Widget build(BuildContext context) {
    DateTime now = DateTime.now();

    List<InvoiceModel> displayedInvoices = _onlyToday
        ? widget.invoices.where((i) => i.date.year == now.year && i.date.month == now.month && i.date.day == now.day).toList()
        : widget.invoices;

    List<PaymentVoucherModel> displayedVouchers = _onlyToday
        ? widget.vouchers.where((v) => v.date.year == now.year && v.date.month == now.month && v.date.day == now.day).toList()
        : widget.vouchers;

    double sales = displayedInvoices.where((i) => i.type == InvoiceType.sales).fold(0, (s, i) => s + i.totalAmount);
    double salesGrossProfit = displayedInvoices.where((i) => i.type == InvoiceType.sales).fold(0, (s, i) => s + i.totalProfit);
    double expenses = displayedVouchers.fold(0, (s, v) => s + v.amount);
    double netProfit = salesGrossProfit - expenses;

    // إحصائيات حركة المواد (الأكثر مبيعاً)
    Map<String, double> productSalesCount = {};
    for (var inv in widget.invoices.where((i) => i.type == InvoiceType.sales)) {
      for (var item in inv.items) {
        productSalesCount[item.product.name] = (productSalesCount[item.product.name] ?? 0) + item.quantity;
      }
    }
    var sortedTopProducts = productSalesCount.entries.toList()..sort((a, b) => b.value.compareTo(a.value));

    return Directionality(
      textDirection: TextDirection.rtl,
      child: DefaultTabController(
        length: 2,
        child: Scaffold(
          appBar: AppBar(
            automaticallyImplyLeading: false,
            bottom: const TabBar(tabs: [Tab(text: 'التقارير السحابية والأرباح'), Tab(text: 'حركة المواد (الأكثر مبيعاً)')]),
          ),
          body: TabBarView(
            children: [
              Padding(
                padding: const EdgeInsets.all(10.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        ChoiceChip(
                          label: Text(_onlyToday ? 'تقارير اليوم' : 'تقارير شاملة'),
                          selected: _onlyToday,
                          selectedColor: Colors.amber.shade200,
                          onSelected: (v) => setState(() => _onlyToday = v),
                        ),
                        Row(
                          children: [
                            IconButton(onPressed: _exportBackup, icon: const Icon(Icons.backup, color: Colors.blue, size: 26), tooltip: 'نسخ احتياطي شامل'),
                            IconButton(onPressed: _importBackupDialog, icon: const Icon(Icons.restore, color: Colors.teal, size: 26), tooltip: 'استعادة'),
                            IconButton(onPressed: () => _generatePdfReport(displayedInvoices, displayedVouchers), icon: const Icon(Icons.picture_as_pdf, color: Colors.purple, size: 26), tooltip: 'PDF'),
                          ],
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        Expanded(child: Card(child: Padding(padding: const EdgeInsets.all(8), child: Text('إجمالي المبيعات: ${formatNumber(sales)} ل.س')))),
                        Expanded(child: Card(child: Padding(padding: const EdgeInsets.all(8), child: Text('أرباح المبيع: ${formatNumber(salesGrossProfit)} ل.س', style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.green))))),
                      ],
                    ),
                    Row(
                      children: [
                        Expanded(child: Card(child: Padding(padding: const EdgeInsets.all(8), child: Text('المصاريف: ${formatNumber(expenses)} ل.س')))),
                        Expanded(child: Card(child: Padding(padding: const EdgeInsets.all(8), child: Text('الصافي (الأرباح - المصاريف): ${formatNumber(netProfit)} ل.س', style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.purple))))),
                      ],
                    ),
                    const SizedBox(height: 10),
                    const Text('سجل الفواتير المتزامنة سحابياً:', style: TextStyle(fontWeight: FontWeight.bold)),
                    Expanded(
                      child: ListView.builder(
                        itemCount: displayedInvoices.length,
                        itemBuilder: (ctx, idx) {
                          final inv = displayedInvoices.reversed.toList()[idx];
                          bool isSales = inv.type == InvoiceType.sales;
                          String timeStr = "${inv.date.hour.toString().padLeft(2, '0')}:${inv.date.minute.toString().padLeft(2, '0')}";
                          return Card(
                            child: ExpansionTile(
                              title: Text('${isSales ? "مبيع" : "شراء"}: ${inv.partyName} (${formatNumber(inv.totalAmount)} ل.س) [$timeStr]'),
                              trailing: (widget.isAdmin || AppSettings.subAccountCanDeleteInvoice) ? IconButton(icon: const Icon(Icons.delete, color: Colors.red), onPressed: () => widget.onDeleteInvoice(inv)) : null,
                              children: inv.items.map((i) => ListTile(dense: true, title: Text('• ${i.product.name} (${i.unitLabelUsed})'), trailing: Text('${formatDecimal(i.quantity)} × ${formatNumber(i.priceUsed)}'))).toList(),
                            ),
                          );
                        },
                      ),
                    )
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(12.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('أكثر المواد مبيعاً وحركة بالمخزن (عبر السحابة):', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.brown)),
                    const Divider(),
                    Expanded(
                      child: sortedTopProducts.isEmpty
                          ? const Center(child: Text('لا توجد مبيعات مسجلة حتى الآن لحساب الحركة'))
                          : ListView.builder(
                              itemCount: sortedTopProducts.length,
                              itemBuilder: (ctx, idx) {
                                var entry = sortedTopProducts[idx];
                                return Card(
                                  child: ListTile(
                                    leading: CircleAvatar(backgroundColor: Colors.amber.shade700, child: Text('${idx + 1}', style: const TextStyle(color: Colors.white))),
                                    title: Text(entry.key, style: const TextStyle(fontWeight: FontWeight.bold)),
                                    trailing: Text('الكمية المباعة: ${formatDecimal(entry.value)}', style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.green)),
                                  ),
                                );
                              },
                            ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ================= 14. تبويب الإعدادات والتحكم بكلمات المرور =================
class AppSettingsWidget extends StatefulWidget {
  final bool isAdmin;
  final VoidCallback onUpdate;

  const AppSettingsWidget({super.key, required this.isAdmin, required this.onUpdate});

  @override
  State<AppSettingsWidget> createState() => _AppSettingsWidgetState();
}

class _AppSettingsWidgetState extends State<AppSettingsWidget> {
  final TextEditingController _adminPassCtrl = TextEditingController(text: AppSettings.adminPassword);
  final TextEditingController _subPassCtrl = TextEditingController(text: AppSettings.subAccountPassword);

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        appBar: AppBar(title: const Text('الإعدادات وكلمات المرور السحابية'), backgroundColor: Colors.amber.shade800, foregroundColor: Colors.white),
        body: Padding(
          padding: const EdgeInsets.all(16.0),
          child: ListView(
            children: [
              const Text('حالة المزامنة السحابية:', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.brown, fontSize: 16)),
              const Divider(),
              const ListTile(
                leading: Icon(Icons.cloud, color: Colors.teal, size: 30),
                title: Text('متصل بقاعدة بيانات Firebase'),
                subtitle: Text('جميع فواتير المبيع ونقاط البيع تتزامن لحظياً في الوقت الفعلي.'),
              ),
              const SizedBox(height: 20),
              const Text('إعدادات كلمات المرور وصلاحيات الحساب الفرعي:', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.brown, fontSize: 16)),
              const Divider(),
              TextField(
                controller: _adminPassCtrl,
                obscureText: true,
                decoration: const InputDecoration(labelText: 'كلمة مرور حساب المدير الجديد', border: OutlineInputBorder()),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _subPassCtrl,
                obscureText: true,
                decoration: const InputDecoration(labelText: 'كلمة مرور نقطة المبيع / الحساب الفرعي', border: OutlineInputBorder()),
              ),
              const SizedBox(height: 16),
              SwitchListTile(
                title: const Text('السماح للحساب الفرعي بحذف الفواتير'),
                value: AppSettings.subAccountCanDeleteInvoice,
                onChanged: widget.isAdmin ? (v) => setState(() => AppSettings.subAccountCanDeleteInvoice = v) : null,
              ),
              SwitchListTile(
                title: const Text('السماح للحساب الفرعي بالوصول للتقارير والأرباح'),
                value: AppSettings.subAccountCanAccessReports,
                onChanged: widget.isAdmin ? (v) => setState(() => AppSettings.subAccountCanAccessReports = v) : null,
              ),
              const SizedBox(height: 30),
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(backgroundColor: Colors.amber.shade800, foregroundColor: Colors.white, minimumSize: const Size.fromHeight(48)),
                onPressed: () {
                  if (widget.isAdmin) {
                    AppSettings.adminPassword = _adminPassCtrl.text.trim();
                    AppSettings.subAccountPassword = _subPassCtrl.text.trim();
                  }
                  widget.onUpdate();
                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('تم حفظ الإعدادات وكلمات المرور بنجاح!'), backgroundColor: Colors.green));
                },
                icon: const Icon(Icons.save),
                label: const Text('حفظ التعديلات العامة', style: TextStyle(fontWeight: FontWeight.bold)),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
