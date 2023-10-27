import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:likeminds_feed/likeminds_feed.dart';
import 'package:likeminds_feed_ss_fl/likeminds_feed_ss_fl.dart';
import 'package:likeminds_feed_ss_fl/src/blocs/new_post/new_post_bloc.dart';
import 'package:likeminds_feed_ss_fl/src/models/post_view_model.dart';
import 'package:likeminds_feed_ss_fl/src/services/bloc_service.dart';
import 'package:likeminds_feed_ss_fl/src/services/likeminds_service.dart';
import 'package:likeminds_feed_ss_fl/src/utils/constants/assets_constants.dart';
import 'package:likeminds_feed_ss_fl/src/utils/constants/ui_constants.dart';
import 'package:likeminds_feed_ss_fl/src/utils/post/post_action_id.dart';
import 'package:likeminds_feed_ss_fl/src/utils/post/post_utils.dart';
import 'package:likeminds_feed_ss_fl/src/utils/utils.dart';
import 'package:likeminds_feed_ss_fl/src/views/likes/likes_screen.dart';
import 'package:likeminds_feed_ss_fl/src/views/media_preview.dart';
import 'package:likeminds_feed_ss_fl/src/views/post/edit_post_screen.dart';
import 'package:likeminds_feed_ss_fl/src/views/post_detail_screen.dart';
import 'package:likeminds_feed_ss_fl/src/widgets/delete_dialog.dart';
import 'package:likeminds_feed_ss_fl/src/widgets/topic/topic_chip_widget.dart';
import 'package:likeminds_feed_ui_fl/likeminds_feed_ui_fl.dart';
import 'package:overlay_support/overlay_support.dart';
import 'package:timeago/timeago.dart' as timeago;
import 'package:url_launcher/url_launcher.dart';

class SSPostWidget extends StatefulWidget {
  final PostViewModel post;
  final User user;
  final Map<String, Topic> topics;
  final bool isFeed;
  final Function() onTap;
  final Function(bool isDeleted) refresh;

  const SSPostWidget({
    Key? key,
    required this.post,
    required this.user,
    required this.onTap,
    required this.topics,
    required this.refresh,
    required this.isFeed,
  }) : super(key: key);

  @override
  State<SSPostWidget> createState() => _SSPostWidgetState();
}

class _SSPostWidgetState extends State<SSPostWidget> {
  int postLikes = 0;
  int comments = 0;
  PostViewModel? postDetails;
  bool? isLiked;
  bool? isPinned;
  ValueNotifier<bool> rebuildLikeWidget = ValueNotifier(false);
  ValueNotifier<bool> rebuildPostWidget = ValueNotifier(false);
  User user = UserLocalPreference.instance.fetchUserData();

  @override
  void initState() {
    super.initState();
    setPostDetails();
  }

  @override
  void didUpdateWidget(covariant SSPostWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    setPostDetails();
  }

  removeEditPost() {
    postDetails!.menuItems.removeWhere((element) {
      return element.id == postEditId;
    });
  }

  void setPostDetails() {
    postDetails = widget.post;
    postLikes = postDetails!.likeCount;
    comments = postDetails!.commentCount;
    isLiked = postDetails!.isLiked;
    isPinned = postDetails!.isPinned;
    removeEditPost();
  }

  @override
  Widget build(BuildContext context) {
    Size screenSize = MediaQuery.of(context).size;
    NewPostBloc newPostBloc = locator<BlocService>().newPostBlocProvider;
    timeago.setLocaleMessages('en', SSCustomMessages());
    return InheritedPostProvider(
      post: widget.post.toPost(),
      child: Container(
        color: kWhiteColor,
        child: BlocListener(
          bloc: newPostBloc,
          listener: (context, state) {
            if (state is PostPinnedState && state.postId == widget.post.id) {
              isPinned = state.isPinned;
              int? itemIndex = postDetails?.menuItems.indexWhere((element) {
                return (isPinned! && element.id == 2) ||
                    (!isPinned! && element.id == 3);
              });
              if (itemIndex != null && itemIndex != -1) {
                if (postDetails!.menuItems[itemIndex].id == 2) {
                  postDetails!.menuItems[itemIndex] =
                      PopupMenuItemModel(title: "Unpin this Post", id: 3);
                } else if (postDetails!.menuItems[itemIndex].id == 3) {
                  postDetails!.menuItems[itemIndex] =
                      PopupMenuItemModel(title: "Pin this Post", id: 2);
                }
              }
              postDetails!.isPinned = isPinned!;
              rebuildPostWidget.value = !rebuildPostWidget.value;
              newPostBloc.add(UpdatePost(post: postDetails!));
            } else if (state is PostPinError &&
                state.postId == widget.post.id) {
              isPinned = state.isPinned;
              rebuildPostWidget.value = !rebuildPostWidget.value;
            }
          },
          child: GestureDetector(
            behavior: HitTestBehavior.deferToChild,
            onTap: () {
              // Navigate to LMPostPage using material route
              if (widget.isFeed) {
                LMAnalytics.get().track(AnalyticsKeys.commentListOpen, {
                  'postId': widget.post.id,
                });
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (context) => PostDetailScreen(
                      postId: widget.post.id,
                    ),
                  ),
                );
              }
            },
            child: Padding(
              padding: const EdgeInsets.symmetric(
                vertical: 18,
                horizontal: 18,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  ValueListenableBuilder(
                    valueListenable: rebuildPostWidget,
                    builder: (context, _, __) => isPinned!
                        ? const Column(
                            children: [
                              Row(
                                children: [
                                  LMIcon(
                                    type: LMIconType.svg,
                                    assetPath: kAssetPinIcon,
                                    color: primary500,
                                    size: 20,
                                  ),
                                  kHorizontalPaddingMedium,
                                  LMTextView(
                                    text: "Pinned Post",
                                    textStyle: TextStyle(color: primary500),
                                  )
                                ],
                              ),
                              kVerticalPaddingMedium,
                            ],
                          )
                        : const SizedBox(),
                  ),
                  ValueListenableBuilder(
                      valueListenable: rebuildPostWidget,
                      builder: (context, _, __) {
                        return LMPostHeader(
                          user: widget.user,
                          isFeed: widget.isFeed,
                          profilePicture: LMProfilePicture(
                            fallbackText: widget.user.name,
                            backgroundColor: kPrimaryColor,
                          ),
                          onProfileTap: () {
                            if (widget.user.sdkClientInfo != null) {
                              locator<LikeMindsService>().routeToProfile(
                                  widget.user.sdkClientInfo!.userUniqueId);
                            }
                          },
                          titleText: LMTextView(
                            text: widget.user.name,
                            textStyle: const TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          subText: LMTextView(
                            text:
                                "@${widget.user.name.toLowerCase().split(" ").join("")}",
                            textStyle: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w400,
                              color: kGreyColor,
                            ),
                          ),
                          createdAt: LMTextView(
                            text: timeago.format(widget.post.createdAt),
                            textStyle: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w400,
                              color: kGreyColor,
                            ),
                          ),
                          menu: LMPostMenu(
                            menuItems: postDetails!.menuItems,
                            onSelected: (id) {
                              FocusScope.of(context).unfocus();
                              if (id == postDeleteId) {
                                // Delete post
                                showDialog(
                                  context: context,
                                  builder: (childContext) {
                                    FocusScope.of(context).unfocus();
                                    return deleteConfirmationDialog(
                                      childContext,
                                      title: 'Delete Post',
                                      userId: postDetails!.userId,
                                      content:
                                          'Are you sure you want to delete this post. This action can not be reversed.',
                                      action: (String reason) async {
                                        Navigator.of(childContext).pop();
                                        final res =
                                            await locator<LikeMindsService>()
                                                .getMemberState();

                                        String? postType =
                                            postDetails!.attachments == null ||
                                                    postDetails!
                                                        .attachments!.isEmpty
                                                ? 'text'
                                                : getPostType(postDetails!
                                                        .attachments
                                                        ?.first
                                                        .attachmentType ??
                                                    0);
                                        //Implement delete post analytics tracking
                                        LMAnalytics.get().track(
                                          AnalyticsKeys.postDeleted,
                                          {
                                            "user_state": res.state == 1
                                                ? "CM"
                                                : "member",
                                            "post_id": postDetails!.id,
                                            "user_id": postDetails!.userId,
                                            "post_type": postType,
                                          },
                                        );
                                        newPostBloc.add(
                                          DeletePost(
                                            postId: postDetails!.id,
                                            reason: reason ?? 'Self Post',
                                          ),
                                        );

                                        widget.refresh(true);
                                      },
                                      actionText: 'Delete',
                                    );
                                  },
                                );
                              } else if (id == postPinId || id == postUnpinId) {
                                String? postType =
                                    postDetails!.attachments == null ||
                                            postDetails!.attachments!.isEmpty
                                        ? 'text'
                                        : getPostType(postDetails!.attachments
                                                ?.first.attachmentType ??
                                            0);
                                if (isPinned!) {
                                  LMAnalytics.get()
                                      .track(AnalyticsKeys.postUnpinned, {
                                    "created_by_id": postDetails!.userId,
                                    "post_id": postDetails!.id,
                                    "post_type": postType,
                                  });
                                } else {
                                  LMAnalytics.get()
                                      .track(AnalyticsKeys.postPinned, {
                                    "created_by_id": postDetails!.userId,
                                    "post_id": postDetails!.id,
                                    "post_type": postType,
                                  });
                                }

                                newPostBloc.add(TogglePinPost(
                                    postId: postDetails!.id,
                                    isPinned: !isPinned!));
                              } else if (id == postEditId) {
                                String? postType =
                                    postDetails!.attachments == null ||
                                            postDetails!.attachments!.isEmpty
                                        ? 'text'
                                        : getPostType(postDetails!.attachments
                                                ?.first.attachmentType ??
                                            0);
                                LMAnalytics.get()
                                    .track(AnalyticsKeys.postEdited, {
                                  "created_by_id": postDetails!.userId,
                                  "post_id": postDetails!.id,
                                  "post_type": postType,
                                });
                                Navigator.of(context).push(MaterialPageRoute(
                                    builder: (context) => EditPostScreen(
                                          postId: postDetails!.id,
                                        )));
                              }
                            },
                            isFeed: widget.isFeed,
                          ),
                        );
                      }),
                  const SizedBox(height: 2),
                  postDetails!.topics.isEmpty ||
                          widget.topics[postDetails!.topics.first] == null
                      ? const SizedBox()
                      : TopicChipWidget(
                          postTopic: TopicUI.fromTopic(
                              widget.topics[postDetails!.topics.first]!),
                        ),
                  LMPostContent(
                    onTagTap: (String userId) {
                      locator<LikeMindsService>().routeToProfile(userId);
                    },
                  ),
                  postDetails!.attachments != null &&
                          postDetails!.text.isNotEmpty
                      ? const SizedBox(height: 10)
                      : const SizedBox(),
                  postDetails!.attachments != null &&
                          postDetails!.attachments!.isNotEmpty
                      ? postDetails!.attachments!.first.attachmentType == 4
                          ? LMLinkPreview(
                              attachment: postDetails!.attachments![0],
                              backgroundColor: kSecondary100,
                              showLinkUrl: false,
                              onTap: () {
                                if (postDetails!.attachments!.first
                                        .attachmentMeta.url !=
                                    null) {
                                  launchUrl(
                                    Uri.parse(postDetails!.attachments!.first
                                        .attachmentMeta.url!),
                                    mode: LaunchMode.externalApplication,
                                  );
                                }
                              },
                              border: Border.all(
                                width: 1,
                                color: kSecondary100,
                              ),
                              title: LMTextView(
                                text: postDetails!.attachments!.first
                                        .attachmentMeta.ogTags?.title ??
                                    "--",
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                textStyle: const TextStyle(
                                  fontWeight: FontWeight.w600,
                                  color: kHeadingBlackColor,
                                  height: 1.30,
                                ),
                              ),
                              subtitle: LMTextView(
                                text: postDetails!.attachments!.first
                                        .attachmentMeta.ogTags?.description ??
                                    "--",
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                textStyle: const TextStyle(
                                  color: kHeadingBlackColor,
                                  fontWeight: FontWeight.w400,
                                  height: 1.30,
                                ),
                              ),
                            )
                          : SizedBox(
                              child: GestureDetector(
                                behavior: HitTestBehavior.opaque,
                                onTap: () {
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(builder: (context) {
                                      return MediaPreview(
                                        postAttachments:
                                            postDetails!.attachments!,
                                        post: postDetails!.toPost(),
                                        user: widget.user,
                                      );
                                    }),
                                  );
                                },
                                child: LMPostMedia(
                                  attachments: postDetails!.attachments!,
                                  borderRadius: 16.0,
                                  showLinkUrl: false,
                                  backgroundColor: kSecondary100,
                                  documentIcon: const LMIcon(
                                    type: LMIconType.svg,
                                    assetPath: kAssetDocPDFIcon,
                                    size: 50,
                                    boxPadding: 0,
                                    fit: BoxFit.cover,
                                    color: Colors.red,
                                  ),
                                ),
                              ),
                            )
                      : const SizedBox(),
                  const SizedBox(height: 18),
                  ValueListenableBuilder(
                    valueListenable: rebuildLikeWidget,
                    builder:
                        (BuildContext context, dynamic value, Widget? child) {
                      return Row(
                        children: [
                          GestureDetector(
                              onTap: () {
                                Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                        builder: (context) => LikesScreen(
                                              postId: postDetails!.id,
                                            )));
                              },
                              child: LMTextView(
                                  text: postLikes == 1
                                      ? "$postLikes Like"
                                      : "$postLikes Likes")),
                          const Spacer(),
                          LMTextView(
                              text: widget.post.commentCount == 1
                                  ? "${widget.post.commentCount} Comment"
                                  : "${widget.post.commentCount} Comments"),
                        ],
                      );
                    },
                  ),
                  const SizedBox(height: 6),
                  const Divider(),
                  const SizedBox(height: 6),
                  LMPostFooter(
                    alignment: LMAlignment.centre,
                    children: [
                      ValueListenableBuilder(
                          valueListenable: rebuildLikeWidget,
                          builder: (context, _, __) {
                            return LMTextButton(
                              text: const LMTextView(text: "Like"),
                              margin: 0,
                              activeText: const LMTextView(
                                text: "Like",
                                textStyle: TextStyle(
                                  color: primary500,
                                ),
                              ),
                              onTap: () async {
                                if (isLiked!) {
                                  postLikes--;
                                  postDetails!.likeCount -= 1;
                                  postDetails!.isLiked = false;
                                } else {
                                  postLikes++;
                                  postDetails!.likeCount += 1;
                                  postDetails!.isLiked = true;
                                }
                                isLiked = !isLiked!;
                                rebuildLikeWidget.value =
                                    !rebuildLikeWidget.value;

                                final response =
                                    await locator<LikeMindsService>().likePost(
                                        (LikePostRequestBuilder()
                                              ..postId(postDetails!.id))
                                            .build());
                                if (!response.success) {
                                  toast(
                                    response.errorMessage ??
                                        "There was an error liking the post",
                                    duration: Toast.LENGTH_LONG,
                                  );

                                  if (isLiked!) {
                                    postLikes--;
                                    postDetails!.likeCount -= 1;
                                    postDetails!.isLiked = false;
                                  } else {
                                    postLikes++;
                                    postDetails!.likeCount += 1;
                                    postDetails!.isLiked = true;
                                  }
                                  isLiked = !isLiked!;
                                  rebuildLikeWidget.value =
                                      !rebuildLikeWidget.value;
                                } else {
                                  if (!widget.isFeed) {
                                    newPostBloc.add(
                                      UpdatePost(
                                        post: postDetails!,
                                      ),
                                    );
                                  }
                                }
                              },
                              icon: const LMIcon(
                                type: LMIconType.svg,
                                assetPath: kAssetLikeIcon,
                                color: kSecondaryColor700,
                                size: 20,
                                boxPadding: 6,
                              ),
                              activeIcon: const LMIcon(
                                type: LMIconType.svg,
                                assetPath: kAssetLikeFilledIcon,
                                size: 20,
                                boxPadding: 6,
                              ),
                              isActive: isLiked!,
                            );
                          }),
                      const Spacer(),
                      LMTextButton(
                        text: const LMTextView(text: "Comment"),
                        margin: 0,
                        onTap: () {
                          if (widget.isFeed) {
                            LMAnalytics.get()
                                .track(AnalyticsKeys.commentListOpen, {
                              'postId': widget.post.id,
                            });
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => PostDetailScreen(
                                  postId: widget.post.id,
                                  fromCommentButton: true,
                                ),
                              ),
                            );
                          }
                        },
                        icon: const LMIcon(
                          type: LMIconType.svg,
                          assetPath: kAssetCommentIcon,
                          color: kSecondaryColor700,
                          size: 20,
                          boxPadding: 6,
                        ),
                      ),
                      const Spacer(),
                      LMTextButton(
                        text: const LMTextView(text: "Share"),
                        margin: 0,
                        onTap: () {
                          String? postType = postDetails!.attachments == null ||
                                  postDetails!.attachments!.isEmpty
                              ? 'text'
                              : getPostType(postDetails!
                                      .attachments?.first.attachmentType ??
                                  0);
                          LMAnalytics.get().track(AnalyticsKeys.postShared, {
                            "post_id": widget.post.id,
                            "post_type": postType,
                            "user_id": user.userUniqueId,
                          });
                          SharePost().sharePost(widget.post.id);
                        },
                        icon: const LMIcon(
                          type: LMIconType.svg,
                          assetPath: kAssetShareIcon,
                          color: kSecondaryColor700,
                          size: 20,
                          boxPadding: 6,
                        ),
                      ),
                    ],
                    // children: [

                    // ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
