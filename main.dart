import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

const supabaseUrl = 'https://yiddzvzbsyckmgjsfijh.supabase.co';
const supabasePublishableKey = 'sb_publishable_ZHJJT2zUpoHDAFr-wzEqjg_gpiUDTPu';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Supabase.initialize(
    url: supabaseUrl,
    publishableKey: supabasePublishableKey,
  );
  runApp(const BillMateAI());
}

final supabase = Supabase.instance.client;

class BillMateAI extends StatelessWidget {
  const BillMateAI({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'BillMate AI',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.blue),
        useMaterial3: true,
      ),
      home: const AuthGate(),
    );
  }
}

class AuthGate extends StatelessWidget {
  const AuthGate({super.key});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<AuthState>(
      stream: supabase.auth.onAuthStateChange,
      builder: (context, snapshot) {
        if (supabase.auth.currentSession != null) {
          return const HomePage();
        }
        return const LoginPage();
      },
    );
  }
}

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final phone = TextEditingController();
  final otp = TextEditingController();
  bool otpSent = false;
  bool loading = false;
  String? message;

  String normalizedPhone() {
    final number = phone.text.trim();
    return number.startsWith('+') ? number : '+91$number';
  }

  Future<void> sendOtp() async {
    if (phone.text.trim().isEmpty) {
      setState(() => message = 'Enter your mobile number.');
      return;
    }

    setState(() {
      loading = true;
      message = null;
    });

    try {
      await supabase.auth.signInWithOtp(phone: normalizedPhone());
      if (!mounted) return;
      setState(() {
        otpSent = true;
        message = 'OTP sent. Enter the OTP.';
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => message = 'OTP error: $e');
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  Future<void> verifyOtp() async {
    if (otp.text.trim().isEmpty) {
      setState(() => message = 'Enter the OTP.');
      return;
    }

    setState(() {
      loading = true;
      message = null;
    });

    try {
      await supabase.auth.verifyOTP(
        phone: normalizedPhone(),
        token: otp.text.trim(),
        type: OtpType.sms,
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => message = 'Verification error: $e');
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  @override
  void dispose() {
    phone.dispose();
    otp.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Column(
              children: [
                const Icon(Icons.receipt_long, size: 76, color: Colors.blue),
                const SizedBox(height: 18),
                const Text(
                  'BillMate AI',
                  style: TextStyle(fontSize: 32, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                const Text('Simple Billing. Smarter Business.'),
                const SizedBox(height: 35),
                TextField(
                  controller: phone,
                  keyboardType: TextInputType.phone,
                  decoration: const InputDecoration(
                    labelText: 'Mobile number',
                    prefixText: '+91 ',
                    border: OutlineInputBorder(),
                  ),
                ),
                if (otpSent) ...[
                  const SizedBox(height: 14),
                  TextField(
                    controller: otp,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      labelText: 'OTP',
                      border: OutlineInputBorder(),
                    ),
                  ),
                ],
                const SizedBox(height: 18),
                SizedBox(
                  width: double.infinity,
                  height: 52,
                  child: FilledButton(
                    onPressed: loading ? null : (otpSent ? verifyOtp : sendOtp),
                    child: loading
                        ? const SizedBox(
                            width: 22,
                            height: 22,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : Text(otpSent ? 'Verify OTP' : 'Send OTP'),
                  ),
                ),
                if (message != null) ...[
                  const SizedBox(height: 14),
                  Text(message!, textAlign: TextAlign.center),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  int index = 0;

  final pages = const [
    DashboardPage(),
    CustomersPage(),
    ProductsPage(),
    ReportsPage(),
    MorePage(),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: pages[index],
      bottomNavigationBar: NavigationBar(
        selectedIndex: index,
        onDestinationSelected: (value) => setState(() => index = value),
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.dashboard_outlined),
            label: 'Dashboard',
          ),
          NavigationDestination(
            icon: Icon(Icons.people_outline),
            label: 'Customers',
          ),
          NavigationDestination(
            icon: Icon(Icons.inventory_2_outlined),
            label: 'Products',
          ),
          NavigationDestination(
            icon: Icon(Icons.bar_chart_outlined),
            label: 'Reports',
          ),
          NavigationDestination(
            icon: Icon(Icons.more_horiz),
            label: 'More',
          ),
        ],
      ),
      floatingActionButton: index == 0
          ? FloatingActionButton.extended(
              onPressed: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const NewBillPage()),
              ),
              icon: const Icon(Icons.add),
              label: const Text('New Bill'),
            )
          : null,
    );
  }
}

Future<String?> firstBusinessId() async {
  final uid = supabase.auth.currentUser?.id;
  if (uid == null) return null;

  final row = await supabase
      .from('businesses')
      .select('id')
      .eq('owner_id', uid)
      .limit(1)
      .maybeSingle();

  return row?['id'] as String?;
}

class DashboardPage extends StatelessWidget {
  const DashboardPage({super.key});

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<String?>(
      future: firstBusinessId(),
      builder: (context, snapshot) {
        final businessId = snapshot.data;

        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        if (businessId == null) {
          return const Center(
            child: Text('No business found. Complete business setup.'),
          );
        }

        return FutureBuilder<List<Map<String, dynamic>>>(
          future: supabase
              .from('invoices')
              .select('total, balance_due, payment_status')
              .eq('business_id', businessId),
          builder: (context, inv) {
            if (inv.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }

            if (inv.hasError) {
              return Center(child: Text('Error: ${inv.error}'));
            }

            final rows = inv.data ?? [];
            double sales = 0;
            double due = 0;

            for (final r in rows) {
              sales += (r['total'] as num?)?.toDouble() ?? 0;
              due += (r['balance_due'] as num?)?.toDouble() ?? 0;
            }

            return SafeArea(
              child: ListView(
                padding: const EdgeInsets.all(20),
                children: [
                  const Text(
                    'BillMate AI',
                    style: TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 20),
                  Row(
                    children: [
                      Expanded(
                        child: statCard(
                          'Total Sales',
                          '₹${sales.toStringAsFixed(2)}',
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: statCard(
                          'Receivable',
                          '₹${due.toStringAsFixed(2)}',
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(child: statCard('Bills', '${rows.length}')),
                      const SizedBox(width: 12),
                      Expanded(
                        child: statCard('Customers', 'Open Customers'),
                      ),
                    ],
                  ),
                  const SizedBox(height: 25),
                  FilledButton.icon(
                    onPressed: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => const NewBillPage(),
                      ),
                    ),
                    icon: const Icon(Icons.receipt_long),
                    label: const Text('Create New Bill'),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Widget statCard(String title, String value) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title),
            const SizedBox(height: 8),
            Text(
              value,
              style: const TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class CustomersPage extends StatefulWidget {
  const CustomersPage({super.key});

  @override
  State<CustomersPage> createState() => _CustomersPageState();
}

class _CustomersPageState extends State<CustomersPage> {
  Future<List<Map<String, dynamic>>> load() async {
    final id = await firstBusinessId();
    if (id == null) return [];

    return List<Map<String, dynamic>>.from(
      await supabase
          .from('customers')
          .select()
          .eq('business_id', id)
          .order('name'),
    );
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: const Text('Customers')),
        body: FutureBuilder<List<Map<String, dynamic>>>(
          future: load(),
          builder: (context, s) {
            if (s.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }

            if (s.hasError) {
              return Center(child: Text('Error: ${s.error}'));
            }

            final rows = s.data ?? [];

            if (rows.isEmpty) {
              return const Center(child: Text('No customers yet.'));
            }

            return ListView.builder(
              itemCount: rows.length,
              itemBuilder: (_, i) => ListTile(
                leading: const CircleAvatar(
                  child: Icon(Icons.person),
                ),
                title: Text('${rows[i]['name'] ?? ''}'),
                subtitle: Text('${rows[i]['phone'] ?? ''}'),
              ),
            );
          },
        ),
      );
}

class ProductsPage extends StatefulWidget {
  const ProductsPage({super.key});

  @override
  State<ProductsPage> createState() => _ProductsPageState();
}

class _ProductsPageState extends State<ProductsPage> {
  Future<List<Map<String, dynamic>>> load() async {
    final id = await firstBusinessId();
    if (id == null) return [];

    return List<Map<String, dynamic>>.from(
      await supabase
          .from('products')
          .select()
          .eq('business_id', id)
          .order('name'),
    );
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: const Text('Products')),
        body: FutureBuilder<List<Map<String, dynamic>>>(
          future: load(),
          builder: (context, s) {
            if (s.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }

            if (s.hasError) {
              return Center(child: Text('Error: ${s.error}'));
            }

            final rows = s.data ?? [];

            if (rows.isEmpty) {
              return const Center(child: Text('No products yet.'));
            }

            return ListView.builder(
              itemCount: rows.length,
              itemBuilder: (_, i) => ListTile(
                leading: const Icon(Icons.inventory_2_outlined),
                title: Text('${rows[i]['name'] ?? ''}'),
                subtitle: Text('Stock: ${rows[i]['stock'] ?? 0}'),
                trailing: Text('₹${rows[i]['selling_price'] ?? 0}'),
              ),
            );
          },
        ),
      );
}

class ReportsPage extends StatelessWidget {
  const ReportsPage({super.key});

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: const Text('Reports')),
        body: const Center(
          child: Text(
            'Sales, profit, GST and outstanding reports will appear here.',
          ),
        ),
      );
}

class MorePage extends StatelessWidget {
  const MorePage({super.key});

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: const Text('More')),
        body: ListView(
          children: [
            ListTile(
              leading: const Icon(Icons.logout),
              title: const Text('Sign out'),
              onTap: () => supabase.auth.signOut(),
            ),
          ],
        ),
      );
}

class NewBillPage extends StatefulWidget {
  const NewBillPage({super.key});

  @override
  State<NewBillPage> createState() => _NewBillPageState();
}

class _BillLine {
  final String productId;
  final String name;
  final double rate;
  final double cost;
  double qty;

  _BillLine({
    required this.productId,
    required this.name,
    required this.rate,
    required this.cost,
    required this.qty,
  });

  double get total => rate * qty;
}

class _NewBillPageState extends State<NewBillPage> {
  List<Map<String, dynamic>> products = [];
  final List<_BillLine> lines = [];
  String paymentMode = 'cash';
  double paid = 0;
  bool loading = true;

  @override
  void initState() {
    super.initState();
    loadProducts();
  }

  Future<void> loadProducts() async {
    try {
      final id = await firstBusinessId();

      if (id != null) {
        products = List<Map<String, dynamic>>.from(
          await supabase
              .from('products')
              .select()
              .eq('business_id', id)
              .order('name'),
        );
      }
    } catch (_) {
      products = [];
    }

    if (mounted) {
      setState(() => loading = false);
    }
  }

  double get subtotal => lines.fold(0, (a, b) => a + b.total);

  void addProduct(Map<String, dynamic> p) {
    final id = '${p['id']}';
    final existing = lines.where((x) => x.productId == id).toList();

    if (existing.isNotEmpty) {
      existing.first.qty++;
    } else {
      lines.add(
        _BillLine(
          productId: id,
          name: '${p['name']}',
          rate: (p['selling_price'] as num?)?.toDouble() ?? 0,
          cost: (p['purchase_price'] as num?)?.toDouble() ?? 0,
          qty: 1,
        ),
      );
    }

    setState(() {});
  }

  Future<void> saveBill() async {
    if (lines.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Add at least one product.')),
      );
      return;
    }

    if (paid < 0 || paid > subtotal) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Paid amount is invalid.')),
      );
      return;
    }

    final businessId = await firstBusinessId();

    if (businessId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No business found.')),
      );
      return;
    }

    setState(() => loading = true);

    try {
      final result = await supabase.rpc(
        'create_invoice_transaction',
        params: {
          'p_business_id': businessId,
          'p_customer_id': null,
          'p_invoice_date': DateTime.now().toIso8601String(),
          'p_discount': 0,
          'p_tax': 0,
          'p_notes': null,
          'p_payment_mode': paymentMode,
          'p_paid_amount': paid,
          'p_items': lines
              .map(
                (x) => {
                  'product_id': x.productId,
                  'quantity': x.qty,
                  'unit_price': x.rate,
                  'discount': 0,
                  'tax_rate': 0,
                },
              )
              .toList(),
        },
      );

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Bill created: $result')),
      );

      Navigator.pop(context);
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Save failed: $e')),
      );
    } finally {
      if (mounted) {
        setState(() => loading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: const Text('New Bill')),
        body: loading && products.isEmpty
            ? const Center(child: CircularProgressIndicator())
            : ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  DropdownButtonFormField<String>(
                    decoration: const InputDecoration(
                      labelText: 'Add product',
                      border: OutlineInputBorder(),
                    ),
                    items: products
                        .map(
                          (p) => DropdownMenuItem<String>(
                            value: '${p['id']}',
                            child: Text('${p['name']}'),
                          ),
                        )
                        .toList(),
                    onChanged: (value) {
                      if (value == null) return;

                      final product = products.firstWhere(
                        (p) => '${p['id']}' == value,
                      );

                      addProduct(product);
                    },
                  ),
                  const SizedBox(height: 20),
                  ...lines.map(
                    (l) => Card(
                      child: ListTile(
                        title: Text(l.name),
                        subtitle: Text(
                          '${l.qty} × ₹${l.rate.toStringAsFixed(2)}',
                        ),
                        trailing: Text(
                          '₹${l.total.toStringAsFixed(2)}',
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                  ),
                  const Divider(),
                  Text(
                    'Total: ₹${subtotal.toStringAsFixed(2)}',
                    style: const TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                    decoration: const InputDecoration(
                      labelText: 'Paid amount',
                      border: OutlineInputBorder(),
                    ),
                    onChanged: (v) {
                      setState(() {
                        paid = double.tryParse(v) ?? 0;
                      });
                    },
                  ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<String>(
                    initialValue: paymentMode,
                    decoration: const InputDecoration(
                      labelText: 'Payment mode',
                      border: OutlineInputBorder(),
                    ),
                    items: const [
                      DropdownMenuItem(
                        value: 'cash',
                        child: Text('Cash'),
                      ),
                      DropdownMenuItem(
                        value: 'upi',
                        child: Text('UPI'),
                      ),
                      DropdownMenuItem(
                        value: 'bank',
                        child: Text('Bank'),
                      ),
                      DropdownMenuItem(
                        value: 'credit',
                        child: Text('Credit'),
                      ),
                    ],
                    onChanged: (v) {
                      setState(() {
                        paymentMode = v ?? 'cash';
                      });
                    },
                  ),
                  const SizedBox(height: 18),
                  FilledButton.icon(
                    onPressed: loading ? null : saveBill,
                    icon: const Icon(Icons.save),
                    label: const Text('Save Bill'),
                  ),
                ],
              ),
      );
}
