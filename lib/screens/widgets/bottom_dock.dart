import 'package:flutter/material.dart';

import '../../theme.dart';

enum DockItem { hub, route, add, config }

class BottomDock extends StatelessWidget {
  const BottomDock({
    super.key,
    required this.active,
    required this.onSelect,
    required this.hubLabel,
    required this.addLabel,
    required this.routeLabel,
    required this.configLabel,
  });

  final DockItem active;
  final ValueChanged<DockItem> onSelect;
  final String hubLabel;
  final String addLabel;
  final String routeLabel;
  final String configLabel;

  @override
  Widget build(BuildContext context) {
    final t = VoidTokens.of(context);
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 14),
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: t.surface,
        border: Border.all(color: t.border),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _DockBtn(
            label: hubLabel,
            isActive: active == DockItem.hub,
            onTap: () => onSelect(DockItem.hub),
            child: const _TriIcon(),
          ),
          _DockBtn(
            label: addLabel,
            isActive: active == DockItem.add,
            onTap: () => onSelect(DockItem.add),
            child: Icon(
              Icons.add_rounded,
              size: 20,
              color: _color(t, active == DockItem.add),
            ),
          ),
          _DockBtn(
            label: routeLabel,
            isActive: active == DockItem.route,
            onTap: () => onSelect(DockItem.route),
            child: Icon(
              Icons.alt_route_rounded,
              size: 18,
              color: _color(t, active == DockItem.route),
            ),
          ),
          _DockBtn(
            label: configLabel,
            isActive: active == DockItem.config,
            onTap: () => onSelect(DockItem.config),
            child: Icon(
              Icons.settings_outlined,
              size: 18,
              color: _color(t, active == DockItem.config),
            ),
          ),
        ],
      ),
    );
  }

  static Color _color(VoidTokens t, bool active) => active ? t.fg1 : t.fg2;
}

class _DockBtn extends StatelessWidget {
  const _DockBtn({
    required this.label,
    required this.isActive,
    required this.onTap,
    required this.child,
  });

  final String label;
  final bool isActive;
  final VoidCallback onTap;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final t = VoidTokens.of(context);
    return Expanded(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(10),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 6),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(10),
            color: isActive
                ? (t.isDark
                    ? const Color(0x14FFFFFF)
                    : const Color(0x0F0A0B0C))
                : Colors.transparent,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              SizedBox(width: 18, height: 18, child: Center(child: child)),
              const SizedBox(height: 4),
              Text(
                label,
                style: VoidType.mono(
                  fontSize: 8,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 1.6,
                  color: isActive ? t.fg1 : t.fg2,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _TriIcon extends StatelessWidget {
  const _TriIcon();

  @override
  Widget build(BuildContext context) {
    final t = VoidTokens.of(context);
    return CustomPaint(
      size: const Size(14, 14),
      painter: _SolidTrianglePainter(color: t.fg1),
    );
  }
}

class _SolidTrianglePainter extends CustomPainter {
  _SolidTrianglePainter({required this.color});
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    final path = Path()
      ..moveTo(w / 2, 2)
      ..lineTo(w - 2, h - 2)
      ..lineTo(2, h - 2)
      ..close();
    canvas.drawPath(path, Paint()..color = color);
  }

  @override
  bool shouldRepaint(covariant _SolidTrianglePainter old) =>
      old.color != color;
}
