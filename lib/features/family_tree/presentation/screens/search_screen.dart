import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/localization/app_localizations.dart';
import '../../models/family_member.dart';
import '../../providers/family_tree_providers.dart';
import '../widgets/member_avatar_widget.dart';
import '../widgets/member_preview_sheet.dart';

class SearchScreen extends ConsumerStatefulWidget {
  const SearchScreen({super.key});

  @override
  ConsumerState<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends ConsumerState<SearchScreen> {
  final TextEditingController _searchController = TextEditingController();
  String _selectedGender = 'all';
  String _selectedStatus = 'all';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final loc = AppLocalizations.of(context);
    final membersMap = ref.watch(familyMembersMapProvider);
    final members = membersMap.values.toList();
    final query = _searchController.text.trim().toLowerCase();

    // Filter results
    final filtered = members.where((m) {
      // Gender filter
      if (_selectedGender != 'all' && m.gender != _selectedGender) {
        return false;
      }
      // Status filter
      if (_selectedStatus != 'all' && m.aliveStatus.name != _selectedStatus) {
        return false;
      }

      if (query.isEmpty) return true;

      // 1. English name match
      final matchEn = m.nameEn.toLowerCase().contains(query);
      // 2. Urdu name match
      final matchUr = m.nameUr.toLowerCase().contains(query);
      // 3. ID match
      final matchId = m.id.toLowerCase().contains(query);
      // 4. Father name match
      bool matchFather = false;
      if (m.fatherId != null && membersMap.containsKey(m.fatherId)) {
        final father = membersMap[m.fatherId]!;
        matchFather = father.nameEn.toLowerCase().contains(query) ||
            father.nameUr.toLowerCase().contains(query);
      }

      return matchEn || matchUr || matchId || matchFather;
    }).toList();

    return Scaffold(
      appBar: AppBar(
        title: Text(loc.translate('search')),
      ),
      body: Column(
        children: [
          // Search input
          Padding(
            padding: const EdgeInsets.all(16),
            child: TextField(
              controller: _searchController,
              onChanged: (_) => setState(() {}),
              decoration: InputDecoration(
                hintText: loc.translate('search_placeholder'),
                prefixIcon: const Icon(Icons.search, color: AppColors.gold),
                suffixIcon: _searchController.text.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear, size: 18),
                        onPressed: () {
                          _searchController.clear();
                          setState(() {});
                        },
                      )
                    : null,
              ),
            ),
          ),

          // Filters Row
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children: [
                _buildFilterChip('All Genders', 'all', _selectedGender, (val) {
                  setState(() => _selectedGender = val);
                }),
                const SizedBox(width: 8),
                _buildFilterChip('Male Only', 'male', _selectedGender, (val) {
                  setState(() => _selectedGender = val);
                }),
                const SizedBox(width: 8),
                _buildFilterChip('Female Only', 'female', _selectedGender, (val) {
                  setState(() => _selectedGender = val);
                }),
                const SizedBox(width: 16),
                _buildFilterChip('All Statuses', 'all', _selectedStatus, (val) {
                  setState(() => _selectedStatus = val);
                }),
                const SizedBox(width: 8),
                _buildFilterChip('Alive', 'alive', _selectedStatus, (val) {
                  setState(() => _selectedStatus = val);
                }),
                const SizedBox(width: 8),
                _buildFilterChip('Deceased', 'deceased', _selectedStatus, (val) {
                  setState(() => _selectedStatus = val);
                }),
              ],
            ),
          ),
          const SizedBox(height: 12),

          // Result count
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Align(
              alignment: Alignment.centerLeft,
              child: Text(
                '${filtered.length} ${filtered.length == 1 ? "member" : "members"} found',
                style: const TextStyle(fontSize: 12, color: AppColors.textLightSecondary),
              ),
            ),
          ),
          const SizedBox(height: 8),

          // Results list
          Expanded(
            child: filtered.isEmpty
                ? Center(
                    child: Text(
                      loc.translate('no_members_found'),
                      style: const TextStyle(color: AppColors.textLightSecondary),
                    ),
                  )
                : ListView.builder(
                    itemCount: filtered.length,
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    itemBuilder: (context, index) {
                      final member = filtered[index];
                      final father = member.fatherId != null
                          ? membersMap[member.fatherId]
                          : null;

                      return Card(
                        margin: const EdgeInsets.only(bottom: 10),
                        child: ListTile(
                          leading: MemberAvatarWidget(member: member, radius: 22),
                          title: Text(
                            member.localizedName(loc.locale.languageCode),
                            style: const TextStyle(fontWeight: FontWeight.bold),
                          ),
                          subtitle: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              if (member.secondaryName(loc.locale.languageCode).isNotEmpty)
                                Text(
                                  member.secondaryName(loc.locale.languageCode),
                                  style: const TextStyle(fontSize: 11, color: AppColors.textLightSecondary),
                                ),
                              if (father != null)
                                Text(
                                  '${loc.translate("father")}: ${father.localizedName(loc.locale.languageCode)}',
                                  style: const TextStyle(fontSize: 11, color: AppColors.goldLight),
                                ),
                            ],
                          ),
                          trailing: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              Text(
                                '${loc.translate("generation")} ${member.generation}',
                                style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600),
                              ),
                              if (member.aliveStatus != AliveStatus.unknown) ...[
                                const SizedBox(height: 4),
                                Text(
                                  loc.isUrdu ? member.aliveStatus.labelUr : member.aliveStatus.labelEn,
                                  style: TextStyle(
                                    fontSize: 10,
                                    color: member.aliveStatus == AliveStatus.alive
                                        ? AppColors.aliveColor
                                        : AppColors.textLightSecondary,
                                  ),
                                ),
                              ],
                            ],
                          ),
                          onTap: () {
                            MemberPreviewSheet.show(context, member);
                          },
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterChip(
    String label,
    String value,
    String currentValue,
    ValueChanged<String> onSelected,
  ) {
    final isSelected = currentValue == value;
    return ChoiceChip(
      label: Text(label, style: TextStyle(fontSize: 11, color: isSelected ? Colors.black : Colors.white)),
      selected: isSelected,
      selectedColor: AppColors.emerald,
      backgroundColor: AppColors.darkCard,
      onSelected: (_) => onSelected(value),
    );
  }
}
