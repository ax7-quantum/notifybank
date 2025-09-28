import 'package:flutter/material.dart';
import 'sms_tab/send_sms_tab.dart';
import 'sms_tab/sms_history_tab.dart';

class SmsManagerView extends StatefulWidget {
  const SmsManagerView({Key? key}) : super(key: key);

  @override
  State<SmsManagerView> createState() => _SmsManagerViewState();
}

class _SmsManagerViewState extends State<SmsManagerView> with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Quản lý tin nhắn SMS'),
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(text: 'Gửi tin nhắn'),
            Tab(text: 'Lịch sử tin nhắn'),
          ],
          labelColor: Colors.blue,
          unselectedLabelColor: Colors.grey,
          indicatorColor: Colors.blue,
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: const [
          // Tab 1: Gửi tin nhắn
          SendSmsTab(),
          
          // Tab 2: Lịch sử tin nhắn (đã gửi và đã nhận)
          SmsHistoryTab(),
        ],
      ),
    );
  }
}
