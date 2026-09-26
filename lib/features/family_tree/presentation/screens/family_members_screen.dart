import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/localization/app_localizations.dart';
import '../../../../core/presentation/widgets/app_drawer.dart';
import '../../../notifications/presentation/widgets/notification_badge_icon.dart';
import '../../models/family_member.dart';
import '../../providers/family_tree_providers.dart';
import '../widgets/member_avatar_widget.dart';

enum MemberFilter { all, male, female, alive, deceased }

class FamilyMembersScreen extends ConsumerStatefulWidget {
  const FamilyMembersScreen({super.key});

  @override
  ConsumerState<FamilyMembersScreen> createState() => _FamilyMembersScreenState();
}

class _FamilyMembersScreenState extends ConsumerState<FamilyMembersScreen> {
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';
  MemberFilter _selectedFilter = MemberFilter.all;

  @override
  void initState() {
    super.initState();
    _searchController.addListener(() {
      final query = _searchController.text.trim().toLowerCase();
      if (query != _searchQuery) {
        setState(() => _searchQuery = query);
      }
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  List<FamilyMember> _filterMembers(List<FamilyMember> allMembers, Map<String, FamilyMember> membersMap) {
    return allMembers.where((m) {
      // 1. Filter by category
      switch (_selectedFilter) {
        case MemberFilter.all:
          break;
        case MemberFilter.male:
          if (m.isFemale) return false;
          break;
        case MemberFilter.female:
          if (!m.isFemale) return false;
          break;
        case MemberFilter.alive:
          if (m.aliveStatus != AliveStatus.alive) return false;
          break;
        case MemberFilter.deceased:
          if (m.aliveStatus != AliveStatus.deceased) return false;
          break;
      }

      // 2. Filter by search text
      if (_searchQuery.isNotEmpty) {
        final father = m.fatherId != null ? membersMap[m.fatherId] : null;
        final nameEn = m.nameEn.toLowerCase();
        final nameUr = m.nameUr.toLowerCase();
        final fatherName = father != null ? '${father.nameEn} ${father.nameUr}'.toLowerCase() : '';
        final id = m.id.toLowerCase();

        return nameEn.contains(_searchQuery) ||
            nameUr.contains(_searchQuery) ||
            fatherName.contains(_searchQuery) ||
            id.contains(_searchQuery);
      }

      return true;
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final loc = AppLocalizations.of(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final membersMap = ref.watch(familyMembersMapProvider);
    final allMembers = membersMap.values.toList();

    final filteredList = _filterMembers(allMembers, membersMap);

    return Scaffold(
      drawer: const AppDrawer(),
      appBar: AppBar(
        title: Text(loc.translate('family_members')),
        actions: const [
          NotificationBadgeIcon(),
        ],
      ),
      body: Column(
        children: [
          // 1. Search Bar
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
            child: Material(
              elevation: 3,
              shadowColor: Colors.black12,
              borderRadius: BorderRadius.circular(24),
              color: isDark ? AppColors.darkCard : Colors.white,
              child: TextField(
                controller: _searchController,
                decoration: InputDecoration(
                  hintText: loc.isUrdu
                      ? 'نام، والد کا نام یا شناختی کوڈ سے تلاش کریں...'
                      : 'Search by name, father name, or ID...',
                  hintStyle: TextStyle(
                    fontSize: 13,
                    color: isDark ? AppColors.textLightSecondary : AppColors.textDarkSecondary,
                  ),
                  prefixIcon: const Icon(Icons.search, color: AppColors.gold, size: 22),
                  suffixIcon: _searchController.text.isNotEmpty
                      ? IconButton(
                          icon: const Icon(Icons.clear, size: 18),
                          onPressed: () {
                            _searchController.clear();
                            setState(() => _searchQuery = '');
                          },
                        )
                      : null,
                  border: InputBorder.none,
                  enabledBorder: InputBorder.none,
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(24),
                    borderSide: const BorderSide(color: AppColors.gold, width: 1.5),
                  ),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
                ),
              ),
            ),
          ),

          // 2. Filter Chips
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
            child: Row(
              children: [
                _buildFilterChip('All (${allMembers.length})', MemberFilter.all, isDark),
                const SizedBox(width: 8),
                _buildFilterChip(loc.translate('male'), MemberFilter.male, isDark),
                const SizedBox(width: 8),
                _buildFilterChip(loc.translate('female'), MemberFilter.female, isDark),
                const SizedBox(width: 8),
                _buildFilterChip(loc.translate('alive'), MemberFilter.alive, isDark),
                const SizedBox(width: 8),
                _buildFilterChip(loc.translate('deceased'), MemberFilter.deceased, isDark),
              ],
            ),
          ),
          const Divider(height: 12),

          // 3. Member List / Grid (Responsive for phones and tablets)
          Expanded(
            child: filteredList.isEmpty
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.people_outline, size: 64, color: AppColors.textLightSecondary),
                        const SizedBox(height: 14),
                        Text(
                          loc.translate('no_members_found'),
                          style: const TextStyle(fontSize: 15, color: AppColors.textLightSecondary),
                        ),
                      ],
                    ),
                  )
                : LayoutBuilder(
                    builder: (context, constraints) {
                      final isTablet = constraints.maxWidth >= 650;
                      final isWideTablet = constraints.maxWidth >= 1000;

                      if (isTablet) {
                        final crossAxisCount = isWideTablet ? 3 : 2;
                        return GridView.builder(
                          padding: const EdgeInsets.all(16),
                          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                            crossAxisCount: crossAxisCount,
                            crossAxisSpacing: 12,
                            mainAxisSpacing: 12,
                            childAspectRatio: 2.7,
                          ),
                          itemCount: filteredList.length,
                          itemBuilder: (context, index) {
                            return _buildMemberTile(filteredList[index], membersMap, loc, isDark);
                          },
                        );
                      }

                      return ListView.separated(
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                        itemCount: filteredList.length,
                        separatorBuilder: (ctx, i) => const SizedBox(height: 8),
                        itemBuilder: (context, index) {
                          return _buildMemberTile(filteredList[index], membersMap, loc, isDark);
                        },
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterChip(String label, MemberFilter filter, bool isDark) {
    final isSelected = _selectedFilter == filter;
    return ChoiceChip(
      label: Text(
        label,
        style: TextStyle(
          fontSize: 12,
          fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
          color: isSelected ? Colors.white : (isDark ? Colors.white70 : Colors.black87),
        ),
      ),
      selected: isSelected,
      selectedColor: AppColors.emerald,
      backgroundColor: isDark ? AppColors.darkCard : AppColors.lightCard,
      onSelected: (selected) {
        if (selected) setState(() => _selectedFilter = filter);
      },
    );
  }

  Widget _buildMemberTile(
    FamilyMember member,
    Map<String, FamilyMember> membersMap,
    AppLocalizations loc,
    bool isDark,
  ) {
    final father = member.fatherId != null ? membersMap[member.fatherId] : null;

    return Card(
      elevation: isDark ? 0 : 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(
          color: member.isFemale
              ? AppColors.femaleAccent.withValues(alpha: 0.3)
              : AppColors.maleAccent.withValues(alpha: 0.3),
          width: 1,
        ),
      ),
      color: isDark ? AppColors.darkCard : Colors.white,
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () => context.push('/member/${member.id}'),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          child: Row(
            children: [
              // Avatar
              MemberAvatarWidget(member: member, radius: 24),
              const SizedBox(width: 12),

              // Names & Father
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                            member.localizedName(loc.locale.languageCode),
                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14.5),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        if (member.secondaryName(loc.locale.languageCode).isNotEmpty) ...[
                          const SizedBox(width: 6),
                          Flexible(
                            child: Text(
                              '(${member.secondaryName(loc.locale.languageCode)})',
                              style: TextStyle(
                                fontSize: 12,
                                color: isDark ? AppColors.textLightSecondary : AppColors.textDarkSecondary,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text(
                      father != null
                          ? '${loc.isUrdu ? "ولدیت:" : "S/D of"} ${father.localizedName(loc.locale.languageCode)}'
                          : 'Gen ${member.generation}',
                      style: TextStyle(
                        fontSize: 12,
                        color: isDark ? AppColors.textLightSecondary : AppColors.textDarkSecondary,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),

              // Status badge & Generation (Never show unknown)
              Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  if (member.aliveStatus != AliveStatus.unknown) ...[
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color: (member.aliveStatus == AliveStatus.alive
                                ? AppColors.aliveColor
                                : AppColors.deceasedColor)
                            .withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(
                        loc.isUrdu ? member.aliveStatus.labelUr : member.aliveStatus.labelEn,
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                          color: member.aliveStatus == AliveStatus.alive
                              ? AppColors.aliveColor
                              : AppColors.deceasedColor,
                        ),
                      ),
                    ),
                    const SizedBox(height: 4),
                  ],
                  Text(
                    'Gen ${member.generation}',
                    style: const TextStyle(fontSize: 10, color: AppColors.gold, fontWeight: FontWeight.bold),
                  ),
                ],
              ),
              const SizedBox(width: 4),
              const Icon(Icons.arrow_forward_ios, size: 12, color: AppColors.textLightSecondary),
            ],
          ),
        ),
      ),
    );
  }
}
