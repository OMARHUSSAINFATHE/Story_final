import 'package:flutter/material.dart';
import '../status_service/status_service.dart';



// =====================================================
// TEXT STATUS CREATOR SCREEN
// =====================================================
class TextStatusCreator extends StatefulWidget {
  const TextStatusCreator({super.key});

  @override
  State<TextStatusCreator> createState() => _TextStatusCreatorState();
}

class _TextStatusCreatorState extends State<TextStatusCreator> {
  final TextEditingController _contentController = TextEditingController();
  String _selectedVisibility = 'FRIENDS';
  bool _isLoading = false;
  Color _selectedBgColor = const Color(0xFF128C7E);
  double _fontSize = 24.0;

  final List<Color> _bgColors = [
    const Color(0xFF128C7E),
    const Color(0xFF075E54),
    const Color(0xFF1877F2),
    const Color(0xFFE53935),
    const Color(0xFF8E24AA),
    const Color(0xFFF57C00),
    const Color(0xFF000000),
    const Color(0xFF37474F),
  ];

  final Map<String, String> _visibilityOptions = {
    'FRIENDS': 'الأصدقاء',
    'PUBLIC': 'الجميع',
  };

  Future<void> _publishStatus() async {
    if (_contentController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('من فضلك اكتب محتوى الحالة')),
      );
      return;
    }

    setState(() => _isLoading = true);

    final result = await StatusService.createTextStatus(
      content: _contentController.text.trim(),
      visibility: _selectedVisibility,
    );

    setState(() => _isLoading = false);
    if (!mounted) return;

    if (result != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('تم نشر الحالة بنجاح! '),
          backgroundColor: Colors.green,
        ),
      );
      Navigator.pop(context, result);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('حدث خطأ أثناء نشر الحالة'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  @override
  void dispose() {
    _contentController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        leading: IconButton(
          icon: const Icon(Icons.close, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          PopupMenuButton<String>(
            initialValue: _selectedVisibility,
            onSelected: (val) => setState(() => _selectedVisibility = val),
            itemBuilder: (_) => _visibilityOptions.entries
                .map((e) => PopupMenuItem(value: e.key, child: Text(e.value)))
                .toList(),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8),
              child: Row(
                children: [
                  const Icon(Icons.people, color: Colors.white, size: 20),
                  const SizedBox(width: 4),
                  Text(
                    _visibilityOptions[_selectedVisibility]!,
                    style: const TextStyle(color: Colors.white, fontSize: 13),
                  ),
                  const Icon(Icons.arrow_drop_down, color: Colors.white),
                ],
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.only(right: 8),
            child: _isLoading
                ? const Center(
                    child: SizedBox(
                      width: 24,
                      height: 24,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    ),
                  )
                : TextButton(
                    onPressed: _publishStatus,
                    child: const Text(
                      'نشر',
                      style: TextStyle(
                        color: Color(0xFF25D366),
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: Container(
              width: double.infinity,
              color: _selectedBgColor,
              child: Center(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: TextField(
                    controller: _contentController,
                    maxLines: null,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: _fontSize,
                      fontWeight: FontWeight.w600,
                    ),
                    decoration: const InputDecoration(
                      hintText: 'اكتب حالتك هنا...',
                      hintStyle: TextStyle(color: Colors.white54, fontSize: 22),
                      border: InputBorder.none,
                    ),
                    autofocus: true,
                  ),
                ),
              ),
            ),
          ),
          Container(
            color: Colors.grey[900],
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            child: Row(
              children: [
                const Icon(Icons.text_fields, color: Colors.white54, size: 16),
                Expanded(
                  child: Slider(
                    value: _fontSize,
                    min: 14,
                    max: 48,
                    activeColor: const Color(0xFF25D366),
                    inactiveColor: Colors.grey,
                    onChanged: (val) => setState(() => _fontSize = val),
                  ),
                ),
                const Icon(Icons.text_fields, color: Colors.white, size: 24),
              ],
            ),
          ),
          Container(
            height: 64,
            color: Colors.grey[900],
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
              itemCount: _bgColors.length,
              itemBuilder: (_, i) {
                final color = _bgColors[i];
                final isSelected = color == _selectedBgColor;
                return GestureDetector(
                  onTap: () => setState(() => _selectedBgColor = color),
                  child: Container(
                    width: 40,
                    height: 40,
                    margin: const EdgeInsets.only(right: 8),
                    decoration: BoxDecoration(
                      color: color,
                      shape: BoxShape.circle,
                      border: isSelected
                          ? Border.all(color: Colors.white, width: 3)
                          : null,
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
