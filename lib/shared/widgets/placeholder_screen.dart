import 'package:material_ui/material_ui.dart';

/// Simple titled screen used for routes whose feature is not built yet.
class PlaceholderScreen extends StatelessWidget {
  const new({required this.title, super.key});

  final String title;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(title)),
      body: Center(child: Text(title)),
    );
  }
}
