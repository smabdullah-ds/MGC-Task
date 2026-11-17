import 'package:bazaar_sort/shared/utils/l10n.dart';
import 'package:bazaar_sort/shared/widgets/placeholder_screen.dart';
import 'package:material_ui/material_ui.dart';

/// Shop screen.
class ShopScreen extends StatelessWidget {
  const new({super.key});

  @override
  Widget build(BuildContext context) =>
      PlaceholderScreen(title: context.l10n.shop);
}
