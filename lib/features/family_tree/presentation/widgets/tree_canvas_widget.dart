import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/localization/app_localizations.dart';
import '../../../auth/providers/auth_provider.dart';
import '../../models/family_member.dart';
import '../../providers/family_tree_providers.dart';
import 'member_node_card.dart';

/// Clean MyHeritage / Pedigree-inspired family tree canvas.
class TreeCanvasWidget extends ConsumerStatefulWidget {
  final String? initialFocusMemberId;
  final bool isDirectAdmin;

  const TreeCanvasWidget({
    super.key,
    this.initialFocusMemberId,
    this.isDirectAdmin = false,
  });

  @override
  ConsumerState<TreeCanvasWidget> createState() => _TreeCanvasWidgetState();
}

class _TreeCanvasWidgetState extends ConsumerState<TreeCanvasWidget>
    with SingleTickerProviderStateMixin {
  late final TransformationController _transformController;
  late final AnimationController _animationController;
  Animation<Matrix4>? _animation;

  final GlobalKey _viewportKey = GlobalKey();
  final GlobalKey _treeContentKey = GlobalKey();
  final Map<String, GlobalKey> _cardKeys = {};

  final TextEditingController _searchController = TextEditingController();
  final FocusNode _searchFocusNode = FocusNode();

  bool _isSearchOpen = false;
  List<FamilyMember> _searchResults = [];
  int _generationDepth = 99; // Always All Generations
  bool _hasInitialExpanded = false;
  String? _pendingFocusMemberId;

  @override
  void initState() {
    super.initState();
    _transformController = TransformationController();
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 550),
    )..addListener(() {
        if (_animation != null) {
          _transformController.value = _animation!.value;
        }
      });

    _searchController.addListener(_onSearchChanged);

    if (widget.initialFocusMemberId != null &&
        widget.initialFocusMemberId!.isNotEmpty) {
      _pendingFocusMemberId = widget.initialFocusMemberId;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _triggerFocusMember(widget.initialFocusMemberId!);
      });
    }
  }

  @override
  void didUpdateWidget(TreeCanvasWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.initialFocusMemberId != null &&
        widget.initialFocusMemberId!.isNotEmpty &&
        widget.initialFocusMemberId != oldWidget.initialFocusMemberId) {
      _pendingFocusMemberId = widget.initialFocusMemberId;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _triggerFocusMember(widget.initialFocusMemberId!);
      });
    }
  }

  void _triggerFocusMember(String memberId) {
    final membersMap = ref.read(familyMembersMapProvider);
    final target = membersMap[memberId];
    if (target != null) {
      _pendingFocusMemberId = null;
      _selectAndFocusMember(target);
    } else {
      _pendingFocusMemberId = memberId;
    }
  }

  @override
  void dispose() {
    _searchController.removeListener(_onSearchChanged);
    _searchController.dispose();
    _searchFocusNode.dispose();
    _animationController.dispose();
    _transformController.dispose();
    super.dispose();
  }

  void _onSearchChanged() {
    final query = _searchController.text.trim().toLowerCase();
    if (query.isEmpty) {
      if (mounted) {
        setState(() {
          _searchResults = [];
          _isSearchOpen = false;
        });
      }
      return;
    }

    final members = ref.read(familyMembersMapProvider).values;
    final results = members.where((m) {
      return m.nameEn.toLowerCase().contains(query) ||
          m.nameUr.toLowerCase().contains(query) ||
          m.id.toLowerCase().contains(query);
    }).take(10).toList();

    if (mounted) {
      setState(() {
        _searchResults = results;
        _isSearchOpen = results.isNotEmpty;
      });
    }
  }

  void _selectAndFocusMember(FamilyMember member) {
    _searchController.clear();
    _searchFocusNode.unfocus();
    setState(() {
      _isSearchOpen = false;
      _searchResults = [];
    });

    final notifier = ref.read(familyTreeStateProvider.notifier);
    notifier.selectMember(member.id);

    // Expand all ancestors up to root
    final membersMap = ref.read(familyMembersMapProvider);
    final ancestors = <String>{};
    String? curFather = member.fatherId;
    while (curFather != null && membersMap.containsKey(curFather)) {
      ancestors.add(curFather);
      curFather = membersMap[curFather]?.fatherId;
    }
    notifier.expandNodes(ancestors);

    // Expand member's own children
    if (member.childrenIds.isNotEmpty) {
      notifier.expandNodes([member.id]);
    }

    // Schedule auto-center after branch expands and finishes layout
    Future.delayed(const Duration(milliseconds: 160), () {
      if (mounted) {
        _centerOnMember(member.id);
      }
    });
  }

  void _centerOnMember(String memberId, {int retryCount = 0}) {
    final cardKey = _cardKeys[memberId];
    final cardCtx = cardKey?.currentContext;
    final viewportCtx = _viewportKey.currentContext;

    if (cardCtx != null && viewportCtx != null) {
      final cardBox = cardCtx.findRenderObject() as RenderBox?;
      final viewportBox = viewportCtx.findRenderObject() as RenderBox?;

      if (cardBox != null &&
          viewportBox != null &&
          cardBox.hasSize &&
          viewportBox.hasSize) {
        final cardPosInViewport =
            cardBox.localToGlobal(Offset.zero, ancestor: viewportBox);
        final cardCenter = cardPosInViewport +
            Offset(cardBox.size.width / 2, cardBox.size.height / 2);
        final viewportCenter =
            Offset(viewportBox.size.width / 2, viewportBox.size.height / 2);

        final delta = viewportCenter - cardCenter;

        final currentMatrix = _transformController.value;
        final currentScale = currentMatrix.getMaxScaleOnAxis();

        // Adjust scale to an optimal reading level (0.9 - 1.1) if currently too zoomed out (< 0.65)
        double targetScaleFactor = 1.0;
        if (currentScale < 0.65) {
          targetScaleFactor = (1.0 / currentScale).clamp(0.01, 5.0);
        }

        final target = Matrix4.copy(currentMatrix)
          ..setTranslationRaw(
            currentMatrix.storage[12] + delta.dx,
            currentMatrix.storage[13] + delta.dy,
            0,
          );

        if ((targetScaleFactor - 1.0).abs() > 0.05) {
          final focalPoint = viewportCenter;
          final translationToOrigin =
              Matrix4.translationValues(-focalPoint.dx, -focalPoint.dy, 0.0);
          final scaleMatrix = Matrix4.diagonal3Values(
              targetScaleFactor, targetScaleFactor, 1.0);
          final translationBack =
              Matrix4.translationValues(focalPoint.dx, focalPoint.dy, 0.0);
          final scaledTarget =
              translationBack * scaleMatrix * translationToOrigin * target;
          _animateTransformTo(scaledTarget);
        } else {
          _animateTransformTo(target);
        }
        return;
      }
    }

    // If card is not laid out yet, retry after frame renders
    if (retryCount < 5) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          Future.delayed(Duration(milliseconds: 50 * (retryCount + 1)), () {
            if (mounted) _centerOnMember(memberId, retryCount: retryCount + 1);
          });
        }
      });
    }
  }

  void _animateTransformTo(Matrix4 target) {
    _animation = Matrix4Tween(
      begin: _transformController.value,
      end: target,
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeInOutCubic,
    ));
    _animationController.forward(from: 0.0);
  }

  void _resetZoom() {
    final treeState = ref.read(familyTreeStateProvider);
    final selectedId = treeState.selectedMemberId;
    if (selectedId != null) {
      _centerOnMember(selectedId);
    } else {
      _fitWholeTreeToViewport();
    }
  }

  void _zoomIn() {
    _zoomByFactor(1.4);
  }

  void _zoomOut() {
    _zoomByFactor(1 / 1.4);
  }

  void _zoomByFactor(double factor) {
    final viewportCtx = _viewportKey.currentContext;
    final viewportBox = viewportCtx?.findRenderObject() as RenderBox?;
    final viewportSize = (viewportBox != null && viewportBox.hasSize)
        ? viewportBox.size
        : MediaQuery.of(context).size;

    final focalPoint = Offset(viewportSize.width / 2, viewportSize.height / 2);

    final currentMatrix = _transformController.value;
    final currentScale = currentMatrix.getMaxScaleOnAxis();
    final newScale = (currentScale * factor).clamp(0.0005, 25.0);
    final actualFactor = newScale / currentScale;

    if ((actualFactor - 1.0).abs() < 0.0001) return;

    final translationToOrigin =
        Matrix4.translationValues(-focalPoint.dx, -focalPoint.dy, 0.0);
    final scaleMatrix =
        Matrix4.diagonal3Values(actualFactor, actualFactor, 1.0);
    final translationBack =
        Matrix4.translationValues(focalPoint.dx, focalPoint.dy, 0.0);

    final targetMatrix =
        translationBack * scaleMatrix * translationToOrigin * currentMatrix;

    _animateTransformTo(targetMatrix);
  }

  /// Calculates dynamic viewport bounds and fits the entire rendered family tree inside
  void _fitWholeTreeToViewport() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final treeCtx = _treeContentKey.currentContext;
      final viewportCtx = _viewportKey.currentContext;

      if (treeCtx == null || viewportCtx == null) return;

      final treeBox = treeCtx.findRenderObject() as RenderBox?;
      final viewportBox = viewportCtx.findRenderObject() as RenderBox?;

      if (treeBox == null ||
          viewportBox == null ||
          !treeBox.hasSize ||
          !viewportBox.hasSize) {
        return;
      }

      final treeSize = treeBox.size;
      final viewportSize = viewportBox.size;

      if (treeSize.width <= 0 ||
          treeSize.height <= 0 ||
          viewportSize.width <= 0 ||
          viewportSize.height <= 0) {
        return;
      }

      // Safe viewport paddings accounting for top search and navigation
      const paddingH = 36.0;
      const paddingTop = 96.0;
      const paddingBottom = 72.0;

      final availableW = viewportSize.width - (paddingH * 2);
      final availableH = viewportSize.height - paddingTop - paddingBottom;

      final scaleX = availableW / treeSize.width;
      final scaleY = availableH / treeSize.height;

      double fitScale = math.min(scaleX, scaleY);
      fitScale = fitScale.clamp(0.0005, 4.0);

      // Center the tree content inside the available viewport area
      final contentCenterLocal =
          Offset(treeSize.width / 2, treeSize.height / 2);
      final viewportCenterScreen = Offset(
        viewportSize.width / 2,
        (paddingTop + (viewportSize.height - paddingBottom)) / 2,
      );

      final tx = viewportCenterScreen.dx - (contentCenterLocal.dx * fitScale);
      final ty = viewportCenterScreen.dy - (contentCenterLocal.dy * fitScale);

      final targetMatrix = Matrix4.identity()
        ..translateByDouble(tx, ty, 0.0, 1.0)
        ..scaleByDouble(fitScale, fitScale, 1.0, 1.0);

      _animateTransformTo(targetMatrix);
    });
  }

  void _applyGenerationFilter(int depth) {
    setState(() => _generationDepth = depth);
    final members = ref.read(familyMembersMapProvider).values;
    final toExpand = <String>{};

    // Always expand all nodes with children across all generations
    for (final m in members) {
      if (m.childrenIds.isNotEmpty) {
        toExpand.add(m.id);
      }
    }
    ref.read(familyTreeStateProvider.notifier).setExpandedNodes(toExpand);

    Future.delayed(const Duration(milliseconds: 220), () {
      if (mounted) _fitWholeTreeToViewport();
    });
  }

  @override
  Widget build(BuildContext context) {
    final loc = AppLocalizations.of(context);
    final isUrdu = loc.isUrdu;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final membersMap = ref.watch(familyMembersMapProvider);
    final treeState = ref.watch(familyTreeStateProvider);

    // Listen to global focus target provider
    ref.listen<String?>(treeFocusTargetProvider, (prev, next) {
      if (next != null && next.isNotEmpty) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          _triggerFocusMember(next);
          ref.read(treeFocusTargetProvider.notifier).state = null;
        });
      }
    });

    if (membersMap.isEmpty) {
      return const Center(
        child: CircularProgressIndicator(color: AppColors.emerald),
      );
    }

    // Auto-expand default generation depth on initial data load
    if (!_hasInitialExpanded && membersMap.isNotEmpty) {
      _hasInitialExpanded = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _applyGenerationFilter(_generationDepth);
        if (_pendingFocusMemberId != null) {
          final target = membersMap[_pendingFocusMemberId];
          if (target != null) {
            _selectAndFocusMember(target);
          }
          _pendingFocusMemberId = null;
        }
      });
    } else if (_pendingFocusMemberId != null &&
        membersMap.containsKey(_pendingFocusMemberId)) {
      final target = membersMap[_pendingFocusMemberId];
      if (target != null) {
        _pendingFocusMemberId = null;
        WidgetsBinding.instance.addPostFrameCallback((_) {
          _selectAndFocusMember(target);
        });
      }
    }

    // Identify roots
    final rootMembers = membersMap.values
        .where((m) => m.fatherId == null || !membersMap.containsKey(m.fatherId))
        .toList();

    return Stack(
      key: _viewportKey,
      children: [
        // 1. Pure 2D Infinite Interactive Tree Viewport (Zero conflicting scroll views)
        Positioned.fill(
          child: InteractiveViewer(
            transformationController: _transformController,
            boundaryMargin: const EdgeInsets.all(double.infinity),
            minScale: 0.0005,
            maxScale: 25.0,
            clipBehavior: Clip.none,
            constrained: false,
            trackpadScrollCausesScale: true,
            child: KeyedSubtree(
              key: _treeContentKey,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 160, vertical: 120),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Root Header Badge
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      decoration: BoxDecoration(
                        color: isDark ? AppColors.darkCard : Colors.white,
                        borderRadius: BorderRadius.circular(24),
                        border: Border.all(color: AppColors.gold, width: 1.5),
                        boxShadow: [
                          BoxShadow(
                            color: AppColors.gold.withValues(alpha: 0.25),
                            blurRadius: 14,
                          ),
                        ],
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.account_tree, color: AppColors.gold, size: 18),
                          const SizedBox(width: 8),
                          Text(
                            isUrdu ? 'خاندانی شجرہ نسب (لغاری خاندان)' : 'Laghari Clan Family Tree',
                            style: const TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.bold,
                              color: AppColors.gold,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 24),

                    // Roots and Hierarchical Tree
                    _buildRootHierarchy(rootMembers, membersMap, treeState, isDark),
                  ],
                ),
              ),
            ),
          ),
        ),

        // 2. Floating Top Header: Search Bar, Generation Depth & Breadcrumbs
        Positioned(
          top: 14,
          left: 16,
          right: 16,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Search Bar (Always All Generations Active)
              ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 680),
                child: Material(
                  elevation: 6,
                  shadowColor: Colors.black26,
                  borderRadius: BorderRadius.circular(28),
                  color: isDark ? AppColors.darkCard : Colors.white,
                  child: TextField(
                    controller: _searchController,
                    focusNode: _searchFocusNode,
                    decoration: InputDecoration(
                      hintText: isUrdu
                          ? 'کسی بھی فرد کو تلاش کریں (اردو / انگریزی)...'
                          : 'Find a person in family tree...',
                      hintStyle: TextStyle(
                        fontSize: 13,
                        color: isDark
                            ? AppColors.textLightSecondary
                            : AppColors.textDarkSecondary,
                      ),
                      prefixIcon: const Icon(Icons.search, color: AppColors.gold, size: 20),
                      suffixIcon: _searchController.text.isNotEmpty
                          ? IconButton(
                              icon: const Icon(Icons.clear, size: 18),
                              onPressed: () {
                                _searchController.clear();
                                setState(() => _isSearchOpen = false);
                              },
                            )
                          : null,
                      border: InputBorder.none,
                      enabledBorder: InputBorder.none,
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(28),
                        borderSide: const BorderSide(color: AppColors.gold, width: 1.5),
                      ),
                      contentPadding:
                          const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
                    ),
                  ),
                ),
              ),

              // Autocomplete Dropdown
              if (_isSearchOpen && _searchResults.isNotEmpty)
                ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 680, maxHeight: 320),
                  child: Material(
                    elevation: 8,
                    borderRadius: BorderRadius.circular(16),
                    color: isDark ? AppColors.darkCard : Colors.white,
                    child: Container(
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
                        ),
                      ),
                      child: ListView.separated(
                        shrinkWrap: true,
                        padding: const EdgeInsets.symmetric(vertical: 6),
                        itemCount: _searchResults.length,
                        separatorBuilder: (context, index) => Divider(
                          height: 1,
                          color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
                        ),
                        itemBuilder: (ctx, idx) {
                          final m = _searchResults[idx];
                          final father =
                              m.fatherId != null ? membersMap[m.fatherId] : null;

                          return Material(
                            color: Colors.transparent,
                            child: ListTile(
                              dense: true,
                              leading: CircleAvatar(
                                radius: 17,
                                backgroundColor: m.isFemale
                                    ? AppColors.femaleAccent.withValues(alpha: 0.2)
                                    : AppColors.maleAccent.withValues(alpha: 0.2),
                                child: Icon(
                                  m.isFemale ? Icons.female : Icons.male,
                                  color: m.isFemale
                                      ? AppColors.femaleAccent
                                      : AppColors.maleAccent,
                                  size: 17,
                                ),
                              ),
                              title: Row(
                                children: [
                                  Text(
                                    m.nameUr.isNotEmpty ? m.nameUr : m.nameEn,
                                    style: const TextStyle(
                                        fontWeight: FontWeight.bold, fontSize: 13.5),
                                  ),
                                  const SizedBox(width: 6),
                                  Text(
                                    '(${m.nameEn})',
                                    style: TextStyle(
                                      fontSize: 11.5,
                                      color: isDark
                                          ? AppColors.textLightSecondary
                                          : AppColors.textDarkSecondary,
                                    ),
                                  ),
                                ],
                              ),
                              subtitle: Text(
                                father != null
                                    ? '${isUrdu ? "ولدیت:" : "Son/Daughter of"} ${father.localizedName(loc.locale.languageCode)} • Gen ${m.generation}'
                                    : 'Gen ${m.generation}',
                                style: const TextStyle(fontSize: 11),
                              ),
                              trailing: const Icon(Icons.arrow_forward_ios,
                                  size: 13, color: AppColors.gold),
                              onTap: () => _selectAndFocusMember(m),
                            ),
                          );
                        },
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),

        // 3. Floating Quick Toolbar Controls (Bottom-Right)
        Positioned(
          bottom: 24,
          right: 20,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _buildControlButton(
                icon: Icons.fit_screen,
                tooltip: loc.translate('fit_whole_tree'),
                onPressed: _fitWholeTreeToViewport,
                isDark: isDark,
              ),
              const SizedBox(height: 8),
              _buildControlButton(
                icon: Icons.add,
                tooltip: 'Zoom In',
                onPressed: _zoomIn,
                isDark: isDark,
              ),
              const SizedBox(height: 8),
              _buildControlButton(
                icon: Icons.remove,
                tooltip: 'Zoom Out',
                onPressed: _zoomOut,
                isDark: isDark,
              ),
              const SizedBox(height: 8),
              _buildControlButton(
                icon: Icons.filter_center_focus,
                tooltip: 'Center View',
                onPressed: _resetZoom,
                isDark: isDark,
              ),
            ],
          ),
        ),
      ],
    );
  }

  /// Builds roots and their descendant branches
  Widget _buildRootHierarchy(
    List<FamilyMember> rootMembers,
    Map<String, FamilyMember> membersMap,
    FamilyTreeState treeState,
    bool isDark,
  ) {
    if (rootMembers.isEmpty) {
      return const SizedBox.shrink();
    }

    return Row(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (int i = 0; i < rootMembers.length; i++) ...[
          _buildMemberTreeNode(rootMembers[i], membersMap, treeState, isDark),
          if (i < rootMembers.length - 1) const SizedBox(width: 80),
        ],
      ],
    );
  }

  /// Recursively renders a member node card and its orthogonal children branches
  Widget _buildMemberTreeNode(
    FamilyMember member,
    Map<String, FamilyMember> membersMap,
    FamilyTreeState treeState,
    bool isDark,
  ) {
    final isSelected = treeState.selectedMemberId == member.id;
    final isExpanded = treeState.expandedNodeIds.contains(member.id);

    final children = member.childrenIds
        .map((id) => membersMap[id])
        .whereType<FamilyMember>()
        .toList();

    _cardKeys[member.id] ??= GlobalKey();

    final lineColor = isDark
        ? const Color(0xFF90A4AE).withValues(alpha: 0.7)
        : const Color(0xFF78909C);

    final currentUser = ref.watch(currentUserProvider);
    final effectiveIsAdmin = widget.isDirectAdmin || (currentUser?.isAdmin ?? false);

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        // Member Card
        KeyedSubtree(
          key: _cardKeys[member.id],
          child: MemberNodeCard(
            member: member,
            isSelected: isSelected,
            isExpanded: isExpanded,
            isDirectAdmin: effectiveIsAdmin,
            onTap: () {
              // Select and toggle or focus
              _selectAndFocusMember(member);
            },
            onExpandToggle: () {
              ref.read(familyTreeStateProvider.notifier).toggleExpanded(member.id);
            },
          ),
        ),

        // Orthogonal Line Connectors & Children
        if (children.isNotEmpty && isExpanded) ...[
          // Vertical trunk dropping from parent card bottom
          Container(
            width: 2.0,
            height: 22.0,
            color: lineColor,
          ),

          // Children Row
          if (children.length == 1)
            // Single child: unbroken vertical drop
            Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(width: 2.0, height: 18.0, color: lineColor),
                _buildMemberTreeNode(children.first, membersMap, treeState, isDark),
              ],
            )
          else
            // Multiple children: Orthogonal elbow connectors with horizontal bus bar
            Row(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                for (int i = 0; i < children.length; i++) ...[
                  CustomPaint(
                    painter: SiblingHeaderPainter(
                      isFirst: i == 0,
                      isLast: i == children.length - 1,
                      lineColor: lineColor,
                      headerHeight: 20.0,
                    ),
                    child: Padding(
                      padding: const EdgeInsets.only(top: 20.0),
                      child: _buildMemberTreeNode(
                        children[i],
                        membersMap,
                        treeState,
                        isDark,
                      ),
                    ),
                  ),
                  if (i < children.length - 1)
                    Container(
                      width: 28.0,
                      height: 20.0,
                      alignment: Alignment.topCenter,
                      child: Container(
                        height: 2.0,
                        color: lineColor,
                      ),
                    ),
                ],
              ],
            ),
        ],
      ],
    );
  }

  Widget _buildControlButton({
    required IconData icon,
    required String tooltip,
    required VoidCallback onPressed,
    required bool isDark,
  }) {
    return Material(
      color: isDark ? AppColors.darkCard : Colors.white,
      elevation: 4,
      shadowColor: Colors.black38,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        onTap: onPressed,
        borderRadius: BorderRadius.circular(14),
        child: Container(
          width: 42,
          height: 42,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
                color: isDark ? AppColors.darkBorder : AppColors.lightBorder),
          ),
          child: Icon(icon, color: AppColors.gold, size: 20),
        ),
      ),
    );
  }
}

/// Draws orthogonal sibling elbow connector:
/// Horizontal bar running along top, with a drop line right down the center to the card
class SiblingHeaderPainter extends CustomPainter {
  final bool isFirst;
  final bool isLast;
  final Color lineColor;
  final double headerHeight;

  SiblingHeaderPainter({
    required this.isFirst,
    required this.isLast,
    required this.lineColor,
    required this.headerHeight,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = lineColor
      ..strokeWidth = 2.0
      ..style = PaintingStyle.stroke;

    final midX = size.width / 2;
    const topY = 0.0;

    // Horizontal connector bar
    if (!isFirst) {
      canvas.drawLine(const Offset(0, topY), Offset(midX, topY), paint);
    }
    if (!isLast) {
      canvas.drawLine(Offset(midX, topY), Offset(size.width, topY), paint);
    }

    // Vertical drop line directly into child card top
    canvas.drawLine(Offset(midX, topY), Offset(midX, headerHeight), paint);
  }

  @override
  bool shouldRepaint(covariant SiblingHeaderPainter oldDelegate) {
    return oldDelegate.isFirst != isFirst ||
        oldDelegate.isLast != isLast ||
        oldDelegate.lineColor != lineColor ||
        oldDelegate.headerHeight != headerHeight;
  }
}
