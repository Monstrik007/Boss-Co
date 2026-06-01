import 'package:flutter/material.dart';

import '../models/game_models.dart';
import '../theme/app_theme.dart';
import 'office_photo_widgets.dart';

class OfficePhotoDetailScreen extends StatefulWidget {
  const OfficePhotoDetailScreen({
    super.key,
    required this.photo,
    required this.localPlayerId,
    required this.onToggleReaction,
    required this.onAddComment,
  });

  final OfficePhoto photo;
  final String? localPlayerId;
  final void Function(String emoji) onToggleReaction;
  final void Function(String text) onAddComment;

  @override
  State<OfficePhotoDetailScreen> createState() => _OfficePhotoDetailScreenState();
}

class _OfficePhotoDetailScreenState extends State<OfficePhotoDetailScreen> {
  final _commentController = TextEditingController();
  final _scrollController = ScrollController();

  @override
  void dispose() {
    _commentController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _sendComment() {
    final text = _commentController.text.trim();
    if (text.isEmpty) return;
    widget.onAddComment(text);
    _commentController.clear();
    FocusScope.of(context).unfocus();
    Future.delayed(const Duration(milliseconds: 300), () {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final photo = widget.photo;
    final commentCount = photo.comments.length;

    return Scaffold(
      body: Container(
        decoration: AppTheme.gradientBackground(
          colors: [AppTheme.darkBg, const Color(0xFF1a1035), AppTheme.darkBg],
        ),
        child: SafeArea(
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
                child: Row(
                  children: [
                    IconButton(
                      onPressed: () => Navigator.pop(context),
                      icon: const Icon(Icons.arrow_back, color: Colors.white),
                    ),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Пост в офисе',
                            style: TextStyle(fontWeight: FontWeight.w800, fontSize: 17),
                          ),
                          Text(
                            '📸 ${photo.authorName}',
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.white.withValues(alpha: 0.55),
                            ),
                          ),
                        ],
                      ),
                    ),
                    if (commentCount > 0)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: AppTheme.slaveTeal.withValues(alpha: 0.2),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          '$commentCount 💬',
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            color: AppTheme.slaveTeal,
                          ),
                        ),
                      ),
                  ],
                ),
              ),
              Expanded(
                child: ListView(
                  controller: _scrollController,
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                  children: [
                    Container(
                      decoration: AppTheme.glassCard(),
                      clipBehavior: Clip.antiAlias,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          OfficePhotoLongPressZone(
                            photo: photo,
                            localPlayerId: widget.localPlayerId,
                            onToggle: widget.onToggleReaction,
                            child: OfficePhotoPostMedia(
                              photo: photo,
                              localPlayerId: widget.localPlayerId,
                              onToggleReaction: widget.onToggleReaction,
                            ),
                          ),
                          if (photo.caption != null && photo.caption!.isNotEmpty)
                            Padding(
                              padding: const EdgeInsets.fromLTRB(14, 12, 14, 14),
                              child: Text(
                                photo.caption!,
                                style: TextStyle(
                                  fontSize: 14,
                                  height: 1.35,
                                  color: Colors.white.withValues(alpha: 0.85),
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 20),
                    Row(
                      children: [
                        const Icon(Icons.forum_outlined, color: AppTheme.slaveTeal, size: 20),
                        const SizedBox(width: 8),
                        Text(
                          commentCount == 0
                              ? 'Комментарии'
                              : 'Комментарии ($commentCount)',
                          style: const TextStyle(
                            fontWeight: FontWeight.w800,
                            fontSize: 16,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    if (photo.comments.isEmpty)
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(20),
                        decoration: AppTheme.glassCard(),
                        child: Text(
                          'Пока тихо. Напиши первый комментарий 👇',
                          textAlign: TextAlign.center,
                          style: TextStyle(color: Colors.white.withValues(alpha: 0.45)),
                        ),
                      )
                    else
                      ...photo.comments.map(
                        (c) => OfficeCommentTile(comment: c),
                      ),
                  ],
                ),
              ),
              Container(
                padding: EdgeInsets.fromLTRB(
                  16,
                  10,
                  16,
                  10 + MediaQuery.paddingOf(context).bottom,
                ),
                decoration: BoxDecoration(
                  color: AppTheme.cardBg.withValues(alpha: 0.95),
                  border: Border(
                    top: BorderSide(color: Colors.white.withValues(alpha: 0.08)),
                  ),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _commentController,
                        maxLines: 4,
                        minLines: 1,
                        textCapitalization: TextCapitalization.sentences,
                        decoration: InputDecoration(
                          hintText: 'Написать комментарий...',
                          hintStyle: TextStyle(
                            color: Colors.white.withValues(alpha: 0.35),
                          ),
                          filled: true,
                          fillColor: Colors.white.withValues(alpha: 0.06),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(20),
                            borderSide: BorderSide.none,
                          ),
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 12,
                          ),
                        ),
                        onSubmitted: (_) => _sendComment(),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Material(
                      color: AppTheme.slaveTeal,
                      borderRadius: BorderRadius.circular(16),
                      child: InkWell(
                        onTap: _sendComment,
                        borderRadius: BorderRadius.circular(16),
                        child: const Padding(
                          padding: EdgeInsets.all(12),
                          child: Icon(
                            Icons.send_rounded,
                            color: AppTheme.darkBg,
                            size: 22,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
