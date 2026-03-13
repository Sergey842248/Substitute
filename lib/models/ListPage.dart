import 'package:flutter/material.dart';

class ListPage extends StatefulWidget {
  ListPage({
    Key? key,
    required this.title,
    this.smallTitle,
    required this.children,
    this.actions,
    this.animate,
    this.canclePage,
    this.onPop,
    this.onTitleClick,
    this.onRefresh,
  }) : super(key: key);

  final String title;
  final Function? onTitleClick;
  bool? smallTitle;
  bool? animate;
  bool? canclePage;
  Function? onPop;
  final List<Widget> children;
  List<Widget>? actions;
  final Future<void> Function()? onRefresh;

  @override
  State<ListPage> createState() => _ListPageState();
}

class _ListPageState extends State<ListPage> {
  ScrollController controller = ScrollController();
  double topHeight = -10;
  final double cornerRadius = 30;

  @override
  void initState() {
    super.initState();
    controller.addListener(() {
      if (controller.offset == 0) return;
      if (controller.offset < 0) {
        topHeight = -10;
      } else {
        topHeight = 0;
      }
      setState(() {});
    });
  }

  @override
  Widget build(BuildContext context) {
    if (topHeight == -10) topHeight = MediaQuery.of(context).size.height * 0.1;
    widget.actions ??= [];
    widget.animate ??= false;
    widget.smallTitle ??= false;
    widget.onPop ??= () => Navigator.pop(context);

    IconData backIcon = Icons.arrow_back_rounded;

    if (widget.canclePage != null && widget.canclePage == true) {
      backIcon = Icons.clear_rounded;
    }

    return SafeArea(
      child: Container(
        child: Stack(
          children: [
            // HEADER mit konkaven Ecken
            AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              alignment: Alignment.topCenter,
              color: Theme.of(context).backgroundColor,
              height: topHeight,
              child: Stack(
                clipBehavior: Clip.none,
                children: [
                  // Header Content
                  ListView(
                    physics: const NeverScrollableScrollPhysics(),
                    children: [
                      Padding(
                        padding: EdgeInsets.only(
                          top: (topHeight / 5.5).toDouble(),
                          bottom: 10,
                          left: 10,
                        ),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.center,
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Row(
                              crossAxisAlignment: CrossAxisAlignment.center,
                              children: [
                                InkWell(
                                  onTap: () => widget.onPop!(),
                                  child: Container(
                                    alignment: Alignment.center,
                                    padding: const EdgeInsets.all(9),
                                    decoration: BoxDecoration(
                                      borderRadius: const BorderRadius.all(
                                        Radius.circular(100),
                                      ),
                                      color: Theme.of(context).dividerColor,
                                    ),
                                    child: Icon(
                                      backIcon,
                                      size: 19,
                                      color: Theme.of(context).splashColor,
                                    ),
                                  ),
                                ),
                                SizedBox(width: 30),
                                AnimatedOpacity(
                                  duration: Duration(
                                      milliseconds: topHeight == 0 ? 700 : 100),
                                  opacity: topHeight == 0 ? 0 : 1,
                                  child: GestureDetector(
                                    onTap: () {
                                      if (widget.onTitleClick != null) {
                                        widget.onTitleClick!();
                                      }
                                    },
                                    child: Container(
                                      child: Text(
                                        widget.title,
                                        style: TextStyle(
                                          fontSize:
                                          widget.smallTitle! ? 22 : 30,
                                          fontWeight: FontWeight.bold,
                                          fontFamily: 'Questrial',
                                        ),
                                      ),
                                    ),
                                  ),
                                )
                              ],
                            ),
                            Row(
                              crossAxisAlignment: CrossAxisAlignment.center,
                              mainAxisAlignment: MainAxisAlignment.spaceAround,
                              children: widget.actions!,
                            ),
                            SizedBox(width: 5),
                          ],
                        ),
                      ),
                    ],
                  ),

                  // Linke konkave Ecke
                  Positioned(
                    bottom: -cornerRadius,
                    left: 0,
                    child: Container(
                      width: cornerRadius,
                      height: cornerRadius,
                      decoration: BoxDecoration(
                        color: Theme.of(context).backgroundColor,
                      ),
                      child: Container(
                        decoration: BoxDecoration(
                          color: Theme.of(context).scaffoldBackgroundColor,
                          borderRadius: BorderRadius.only(
                            topLeft: Radius.circular(cornerRadius),
                          ),
                        ),
                      ),
                    ),
                  ),

                  // Rechte konkave Ecke
                  Positioned(
                    bottom: -cornerRadius,
                    right: 0,
                    child: Container(
                      width: cornerRadius,
                      height: cornerRadius,
                      decoration: BoxDecoration(
                        color: Theme.of(context).backgroundColor,
                      ),
                      child: Container(
                        decoration: BoxDecoration(
                          color: Theme.of(context).scaffoldBackgroundColor,
                          borderRadius: BorderRadius.only(
                            topRight: Radius.circular(cornerRadius),
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),

            // Collapsed Header Title
            AnimatedOpacity(
              duration: Duration(milliseconds: topHeight == 0 ? 700 : 100),
              opacity: topHeight == 0 ? 1 : 0,
              child: Container(
                alignment: Alignment.topLeft,
                margin: const EdgeInsets.all(20),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    InkWell(
                      onTap: () => widget.onPop!(),
                      child: Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          borderRadius: const BorderRadius.all(
                            Radius.circular(100),
                          ),
                          color: Theme.of(context).dividerColor,
                        ),
                        child: Icon(
                          backIcon,
                          size: 16,
                          color: Theme.of(context).splashColor,
                        ),
                      ),
                    ),
                    SizedBox(width: 20),
                    GestureDetector(
                      onTap: () {
                        if (widget.onTitleClick != null) {
                          widget.onTitleClick!();
                        }
                      },
                      child: Text(
                        widget.title,
                        style: TextStyle(
                          fontSize: 23,
                          fontWeight: FontWeight.w600,
                          fontFamily: 'Questrial',
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),

            // CONTENT
            AnimatedPositioned(
              duration: const Duration(milliseconds: 200),
              top: topHeight + cornerRadius,
              left: 0,
              right: 0,
              bottom: 0,
              child: Container(
                decoration: BoxDecoration(
                  color: Theme.of(context).scaffoldBackgroundColor,
                  borderRadius: BorderRadius.vertical(
                    top: Radius.circular(cornerRadius),
                  ),
                ),
                child: Padding(
                  padding: EdgeInsets.only(
                    top: topHeight != 0 ? 15 : 0,
                    left: 20,
                    right: 20,
                    bottom: 10,
                  ),
                  child: _buildContent(),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildContent() {
    Widget listView = ListView(
      controller: controller,
      physics: const BouncingScrollPhysics(
        parent: AlwaysScrollableScrollPhysics(),
      ),
      children: widget.children,
    );

    if (widget.animate!) {
      listView = AnimatedSwitcher(
        duration: Duration(milliseconds: 500),
        transitionBuilder: (child, animation) => SlideTransition(
          position: Tween<Offset>(
            begin: const Offset(0, 2),
            end: const Offset(0, 0),
          ).animate(animation),
          child: child,
        ),
        child: ListView(
          key: ValueKey(widget.children),
          controller: controller,
          physics: const BouncingScrollPhysics(
            parent: AlwaysScrollableScrollPhysics(),
          ),
          children: widget.children,
        ),
      );
    }

    if (widget.onRefresh != null) {
      return RefreshIndicator(
        onRefresh: widget.onRefresh!,
        displacement: 0,
        strokeWidth: 0,
        color: Colors.transparent,
        backgroundColor: Colors.transparent,
        child: listView,
      );
    }

    return listView;
  }
}