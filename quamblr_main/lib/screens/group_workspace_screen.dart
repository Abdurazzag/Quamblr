import 'package:flutter/material.dart';

class GroupWorkspaceScreen extends StatelessWidget {
  final String title;

  const GroupWorkspaceScreen({
    super.key,
    required this.title,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: const BackButton(),
        title: Text(title),
      ),
      body: const SafeArea(
        child: SizedBox.expand(),
      ),
    );
  }
}