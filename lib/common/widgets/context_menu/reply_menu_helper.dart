part of 'package:pili_plus/pages/video/reply/widgets/reply_item_grpc.dart';

void showReplyCopyDialog(
  BuildContext context,
  String message,
  Map<String, Emote> emotes,
) {
  bool showEmote = false;
  showDialog(
    context: context,
    builder: (context) => Dialog(
      constraints: const BoxConstraints.tightFor(width: 380),
      child: Padding(
        padding: const .symmetric(horizontal: 20, vertical: 16),
        child: SingleChildScrollView(
          child: SelectionText.rich(
            showEmote
                ? TextSpan(
                    children: emotes.entries.mapIndexed(
                      (i, e) {
                        final emote = e.value;
                        final size = emote.size.toInt() * 25.0;
                        return TextSpan(
                          children: [
                            if (i != 0) const TextSpan(text: '\n\n'),
                            WidgetSpan(
                              child: NetworkImgLayer(
                                src: emote.url,
                                type: .emote,
                                width: size,
                                height: size,
                              ),
                            ),
                            TextSpan(text: '\n${e.key}\n${emote.url}'),
                          ],
                        );
                      },
                    ).toList(),
                  )
                : TextSpan(text: message),
            contextMenuBuilder: (_, state) {
              final buttonItems = state.contextMenuButtonItems;
              if (emotes.isNotEmpty) {
                buttonItems.insertOrAdd(
                  3,
                  ContextMenuButtonItem(
                    label: showEmote ? '文本' : '表情',
                    onPressed: () {
                      state
                        ..hideToolbar()
                        ..clearSelection();
                      showEmote = !showEmote;
                      (context as Element).markNeedsBuild();
                    },
                  ),
                );
                if (showEmote) {
                  state.addLaunchMenuIfNeeded(buttonItems, index: 4);
                }
              }
              try {
                if (state.selectionEndpoints.first !=
                    state.selectionEndpoints[1]) {
                  buttonItems.add(
                    ContextMenuButtonItem(
                      onPressed: () {
                        final selectedText = (state as dynamic).selectable
                            ?.getSelectedContent()
                            ?.plainText;
                        String text = RegExp.escape(selectedText);
                        if (ReplyGrpc.enableFilter) text = '|$text';

                        showConfirmDialog(
                          context: context,
                          title: const Text('是否确认评论过滤的变更：'),
                          content: Text.rich(
                            TextSpan(
                              text: ReplyGrpc.replyRegExp.pattern,
                              children: [
                                TextSpan(
                                  text: text,
                                  style: const TextStyle(
                                    color: Colors.green,
                                    fontWeight: .bold,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          onConfirm: () {
                            final filter = ReplyGrpc.replyRegExp.pattern + text;
                            ReplyGrpc.replyRegExp = RegExp(
                              filter,
                              caseSensitive: true,
                            );
                            ReplyGrpc.enableFilter = true;
                            GStorage.setting.put(
                              SettingBoxKey.banWordForReply,
                              filter,
                            );
                            SmartDialog.showToast('已保存');
                          },
                        );
                      },
                      label: '加入过滤',
                    ),
                  );
                }
              } catch (_) {}
              return AdaptiveTextSelectionToolbar.buttonItems(
                buttonItems: buttonItems,
                anchors: state.contextMenuAnchors,
              );
            },
            style: const TextStyle(fontSize: 15, height: 1.7),
          ),
        ),
      ),
    ),
  );
}
