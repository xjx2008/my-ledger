import 'package:flutter/material.dart';

import '../data/app_state.dart';
import '../theme/app_theme.dart';
import 'backup_screen.dart';
import 'categories_screen.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: appState,
      builder: (context, _) {
        final t = appState.theme;
        return Scaffold(
          backgroundColor: t.background,
          body: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(20, 24, 20, 24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('设置', style: TextStyle(fontSize: 22, fontWeight: FontWeight.w500, color: t.text)),
                const SizedBox(height: 20),
                // 分类管理入口
                GestureDetector(
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const CategoriesScreen()),
                  ),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                    decoration: BoxDecoration(color: t.card, borderRadius: BorderRadius.circular(t.radius)),
                    child: Row(
                      children: [
                        Container(
                          width: 38,
                          height: 38,
                          decoration: BoxDecoration(
                            color: t.primary.withOpacity(0.13),
                            borderRadius: BorderRadius.circular(11),
                          ),
                          child: Icon(Icons.category_rounded, color: t.primary, size: 20),
                        ),
                        const SizedBox(width: 13),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('分类管理', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500, color: t.text)),
                              const SizedBox(height: 3),
                              Text('支出/收入分类，支持自定义增删改', style: TextStyle(fontSize: 11, color: t.subText)),
                            ],
                          ),
                        ),
                        Icon(Icons.chevron_right, color: t.subText),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 14),
                GestureDetector(
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const BackupScreen()),
                  ),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                    decoration: BoxDecoration(color: t.card, borderRadius: BorderRadius.circular(t.radius)),
                    child: Row(
                      children: [
                        Container(
                          width: 38,
                          height: 38,
                          decoration: BoxDecoration(
                            color: t.primary.withOpacity(0.13),
                            borderRadius: BorderRadius.circular(11),
                          ),
                          child: Icon(Icons.swap_horiz_rounded, color: t.primary, size: 20),
                        ),
                        const SizedBox(width: 13),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('数据迁移与备份', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500, color: t.text)),
                              const SizedBox(height: 3),
                              Text('升级/换机时导出、导入账目，支持自动快照', style: TextStyle(fontSize: 11, color: t.subText)),
                            ],
                          ),
                        ),
                        Icon(Icons.chevron_right, color: t.subText),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 24),
                Text('主题风格', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w500, color: t.text)),
                const SizedBox(height: 4),
                Text('点一下即时切换，自动记住选择', style: TextStyle(fontSize: 12, color: t.subText)),
                const SizedBox(height: 14),
                GridView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 2,
                    mainAxisSpacing: 12,
                    crossAxisSpacing: 12,
                    childAspectRatio: 1.5,
                  ),
                  itemCount: appThemes.length,
                  itemBuilder: (context, i) {
                    final theme = appThemes[i];
                    final selected = appState.theme.key == theme.key;
                    return GestureDetector(
                      onTap: () => appState.setThemeKey(theme.key),
                      child: Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: theme.background,
                          borderRadius: BorderRadius.circular(12),
                          border: selected
                              ? Border.all(color: theme.primary, width: 2)
                              : Border.all(color: t.subText.withOpacity(0.15)),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Container(
                                  width: 20,
                                  height: 20,
                                  decoration: BoxDecoration(color: theme.primary, borderRadius: BorderRadius.circular(6)),
                                ),
                                if (selected)
                                  Icon(Icons.check_circle, color: theme.primary, size: 18),
                              ],
                            ),
                            Text(theme.name, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w500, color: theme.text)),
                          ],
                        ),
                      ),
                    );
                  },
                ),
                const SizedBox(height: 24),
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(color: t.card, borderRadius: BorderRadius.circular(t.radius)),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('关于', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500, color: t.text)),
                      const SizedBox(height: 10),
                      Text('我的账本 · 本地记账工具', style: TextStyle(fontSize: 12, color: t.subText)),
                      const SizedBox(height: 4),
                      Text('所有数据仅保存在你的手机本地，不联网、不上传。', style: TextStyle(fontSize: 12, color: t.subText)),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
