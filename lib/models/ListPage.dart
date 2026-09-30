import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';

class ListPage extends StatefulWidget {
  ListPage({
    Key? key,
    required this.title,
    this.smallTitle,
    required this.children,
    this.actions,
    this.headerCenter,
    this.canclePage,
    this.onPop,
    this.onTitleClick,
    this.onRefresh,
    this.noSpinnerRefreshIndicator = false,
    this.showBackButton = true,
    this.collapseHeaderOnScroll = true,
    this.keepScrollOffset = true,
  }) : super(key: key);

  final String title;
  final Function? onTitleClick;
  bool? smallTitle;
  bool? canclePage;
  Function? onPop;
  final List<Widget> children;
  List<Widget>? actions;

  /// Eine einzelne Option, die mittig oben in der Kopfzeile steht – z.B. das
  /// Ein-/Ausblenden der Vorschau. Sie sitzt unabhängig von der Länge des
  /// Titels immer in der Mitte der Kopfzeile; Titel und Aktions-Buttons weichen
  /// ihr nach links bzw. rechts aus.
  final Widget? headerCenter;

  /// Wenn false, wird der Zurück-Pfeil ausgeblendet (z.B. auf der
  /// Anmeldeseite, solange noch keine Zugangsdaten hinterlegt sind).
  final bool showBackButton;

  /// Wenn false, bleibt die Kopfzeile vollständig sichtbar, auch wenn der
  /// Inhalt scrollt.
  final bool collapseHeaderOnScroll;

  /// Wenn false, übernimmt die Liste keinen alten PageStorage-Scrollstand.
  final bool keepScrollOffset;

  /// Pull-to-refresh callback. When set, the content list is wrapped in a
  /// RefreshIndicator so a downward pull reloads the page.
  final Future<void> Function()? onRefresh;

  /// Wenn true, wird beim Pull-to-Refresh kein Overlay-Spinner (Material
  /// [RefreshIndicator]) angezeigt – [onRefresh] wird trotzdem ausgeführt.
  /// Der Aufrufer zeigt dann während des Ladevorgangs sein eigenes
  /// Lade-Symbol an (z.B. direkt über dem Inhalt, wie beim Klick auf ein
  /// Aktualisieren-Symbol in der Kopfzeile).
  final bool noSpinnerRefreshIndicator;

  @override
  State<ListPage> createState() => _ListPageState();
}

class _ListPageState extends State<ListPage> {
  late final ScrollController controller;
  final double cornerRadius = 30;

  /// Höhe der Kopfzeile im vollständig ausgeklappten Zustand (10 % der
  /// Bildschirmhöhe).
  double _headerHeight = 0;

  /// Wie stark die Kopfzeile gerade eingeklappt ist: 0 = vollständig
  /// ausgeklappt, [_headerHeight] = vollständig eingeklappt.
  ///
  /// Der Wert folgt **direkt** dem Scroll-Offset (siehe [_onScroll]) und wird
  /// nicht animiert: Jedes eingeklappte Pixel macht den sichtbaren Bereich
  /// genau ein Pixel größer, `maxScrollExtent` der Liste wächst also im selben
  /// Maß wie der Offset. Bliebe die Kopfzeile (wie vorher per Animation)
  /// hinterher, schrumpfte der Scrollbereich unter dem aktuellen Offset,
  /// Flutter klemmte diesen zurück und die Liste sprang wieder nach oben –
  /// genau das passierte, wenn nur ein paar Zeilen unterhalb des Sichtbaren
  /// überstanden.
  double _collapse = 0;

  /// Wird true, sobald der Nutzer die Seite wirklich gescrollt hat. Davor
  /// wird die Kopfzeile nicht eingeklappt – programmatische Scrolls
  /// (Tastatur, Scroll-into-view beim Fokussieren eines Feldes,
  /// wiederhergestellte Scroll-Position) dürfen die Seite beim Öffnen nicht
  /// „hochgeschoben" aussehen lassen, als hätte man bereits gescrollt.
  bool _userScrolled = false;

  /// Höhe der Kopfzeile über den konkaven Ecken, also der Teil, der beim
  /// Scrollen ein- und ausklappt.
  double get topHeight => _headerHeight - _collapse;

  @override
  void initState() {
    super.initState();
    controller = ScrollController(keepScrollOffset: widget.keepScrollOffset);
    controller.addListener(_onScroll);
  }

  void _onScroll() {
    if (!mounted || !controller.hasClients) return;
    final double offset = controller.offset;

    if (offset <= 0) {
      // Ganz oben angekommen: die Nutzer-Geste wird zurückgesetzt, damit
      // programmatische Scrolls (Tastatur, Fokus) die Kopfzeile nicht mehr
      // einklappen.
      _userScrolled = false;
    }

    double collapse = 0;
    if (widget.collapseHeaderOnScroll && _userScrolled && _headerHeight > 0) {
      // Das Einklappen gibt Platz frei, verkleinert aber den Bereich, den die
      // Liste abdecken kann. Übersteigt die Kopfzeilenhöhe den Scrollbereich
      // (also liegen nur ein paar Zeilen unterhalb des Sichtbaren), würde der
      // Inhalt beim Einklappen aus dem Sichtfeld springen und der Offset
      // zurückgeklemmt – die Liste schnellt dann beim Scrollen wieder nach
      // oben. In dem Fall bleibt die Kopfzeile offen.
      //
      // Der Wert wird aus dem aktuellen Zustand zurückgerechnet: Bei
      // eingeklappter Kopfzeile ist der Scrollbereich um genau [_collapse]
      // größer als bei ausgeklappter.
      final double scrollRangeExpanded =
          controller.position.maxScrollExtent - _collapse;
      if (scrollRangeExpanded > _headerHeight) {
        collapse = offset.clamp(0.0, _headerHeight);
      }
    }

    // Nur bei spürbarer Änderung neu aufbauen (der Listener feuert bei jedem
    // Pixel des Scrollens).
    if ((collapse - _collapse).abs() < 0.5) return;
    setState(() => _collapse = collapse);
  }

  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    _headerHeight = MediaQuery.of(context).size.height * 0.1;
    widget.actions ??= [];
    widget.smallTitle ??= false;
    widget.onPop ??= () => Navigator.pop(context);

    IconData backIcon = Icons.arrow_back_rounded;

    if (widget.canclePage != null && widget.canclePage == true) {
      backIcon = Icons.clear_rounded;
    }

    return Material(
      color: Theme.of(context).scaffoldBackgroundColor,
      child: SafeArea(
        child: Container(
          child: Stack(
          children: [
            // HEADER mit konkaven Ecken.
            // Keine Animation der Höhe: Sie muss 1:1 dem Scroll-Offset folgen,
            // sonst wächst der sichtbare Inhaltsbereich schneller als der
            // Scrollbereich der Liste und der Offset wird zurückgeklemmt
            // (die Liste springt dann beim Scrollen wieder nach oben).
            Container(
              key: const ValueKey('listpage_header'),
              alignment: Alignment.topCenter,
              color: Theme.of(context).colorScheme.surface,
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
                        child: Stack(
                          alignment: Alignment.center,
                          children: [
                            // Platz für die mittige Option, damit Titel
                            // und Aktions-Buttons nicht darunter laufen.
                            Padding(
                              padding: EdgeInsets.only(
                                right: widget.headerCenter != null ? 40 : 0,
                              ),
                              child: Row(
                                crossAxisAlignment: CrossAxisAlignment.center,
                                children: [
                                if (widget.showBackButton) ...[
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
                                  SizedBox(width: 12),
                                ],
                                Expanded(
                                  child: Row(
                                    children: [
                                      // Der Titel nimmt den restlichen Platz ein, die
                                      // Aktions-Buttons werden dadurch rechtsbündig
                                      // am rechten Rand angezeigt.
                                      Expanded(
                                        child: AnimatedOpacity(
                                          duration: Duration(
                                              milliseconds: topHeight == 0 ? 700 : 100),
                                          opacity: topHeight == 0 ? 0 : 1,
                                          child: GestureDetector(
                                            onTap: () {
                                              if (widget.onTitleClick != null) {
                                                widget.onTitleClick!();
                                              }
                                            },
                                            child: Text(
                                              widget.title,
                                              overflow: TextOverflow.ellipsis,
                                              maxLines: widget.smallTitle! ? 2 : 1,
                                              style: TextStyle(
                                                fontSize:
                                                widget.smallTitle! ? 22 : 30,
                                                fontWeight: FontWeight.bold,
                                                fontFamily: 'Questrial',
                                              ),
                                            ),
                                          ),
                                        ),
                                      ),
                                      if (widget.actions!.isNotEmpty)
                                        SingleChildScrollView(
                                          scrollDirection: Axis.horizontal,
                                          reverse: true,
                                          child: Row(
                                            mainAxisSize: MainAxisSize.min,
                                            children: widget.actions!,
                                          ),
                                        ),
                                    ],
                                  ),
                                ),
                                SizedBox(width: 5),
                                ],
                              ),
                            ),
                            if (widget.headerCenter != null)
                              widget.headerCenter!,
                          ],
                        ),
                      ),
                    ],
                  ),

                  // left concave corner
                  Positioned(
                    bottom: -cornerRadius,
                    left: 0,
                    child: Container(
                      width: cornerRadius,
                      height: cornerRadius,
                      decoration: BoxDecoration(
                        color: Theme.of(context).colorScheme.surface,
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

                  // right concave corner
                  Positioned(
                    bottom: -cornerRadius,
                    right: 0,
                    child: Container(
                      width: cornerRadius,
                      height: cornerRadius,
                      decoration: BoxDecoration(
                        color: Theme.of(context).colorScheme.surface,
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
            // IgnorePointer: solange die Kopfzeile erweitert ist (topHeight
            // != 0), ist dieser Titel unsichtbar und darf keine Taps
            // abfangen - sonst wuerden die Buttons der erweiterten Kopfzeile
            // (Refresh, Einstellungen, Pfeile) nie einen Tap bekommen.
            IgnorePointer(
              ignoring: topHeight != 0,
              child: AnimatedOpacity(
                duration: Duration(milliseconds: topHeight == 0 ? 700 : 100),
                opacity: topHeight == 0 ? 1 : 0,
                child: Container(
                alignment: Alignment.topLeft,
                margin: const EdgeInsets.all(20),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    if (widget.showBackButton) ...[
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
                    ],
                    Expanded(
                      child: GestureDetector(
                        onTap: () {
                          if (widget.onTitleClick != null) {
                            widget.onTitleClick!();
                          }
                        },
                        child: Text(
                          widget.title,
                          overflow: TextOverflow.ellipsis,
                          maxLines: widget.smallTitle! ? 2 : 1,
                          style: TextStyle(
                            fontSize: 23,
                            fontWeight: FontWeight.w600,
                            fontFamily: 'Questrial',
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              ),
            ),

            // CONTENT
            // Folgt exakt der Einklappung (ohne Animation): Jedes
            // eingeklappte Pixel holt genau ein Pixel Sichtfläche dazu, der
            // Scrollbereich der Liste wächst also im gleichen Maß wie der
            // Offset. Mit einer Animation (oder einem Sprung) schrumpfte der
            // Scrollbereich kurzzeitig unter dem Offset, woraufhin Flutter
            // diesen zurückklemmte und die Liste wieder nach oben sprang.
            Positioned(
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
                  padding: const EdgeInsets.only(
                    // Konstant, damit die Höhe des Inhalts nicht vom
                    // Scroll-Zustand abhängt - davon hängt ab, wie weit die
                    // Liste scrollbar bleibt.
                    top: 15,
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
      ),
    );
  }

  Widget _buildContent() {
  final Widget list = NotificationListener<ScrollNotification>(
    onNotification: (notification) {
      // Nur eine ScrollUpdateNotification mit gesetzten dragDetails stammt
      // von einer echten Finger-Drag-Geste. Programmatische Scrolls (Tastatur/
      // Scroll-into-view beim Fokussieren eines Feldes, wiederhergestellte
      // Scroll-Position via jumpTo/animateTo, o.ä.) haben dragDetails == null
      // und dürfen die Kopfzeile NICHT einklappen lassen.
      if (widget.collapseHeaderOnScroll &&
          notification is ScrollUpdateNotification &&
          notification.dragDetails != null) {
        _userScrolled = true;
      }
      return false;
    },
    child: ListView(
      controller: controller,
      physics: const BouncingScrollPhysics(
        parent: AlwaysScrollableScrollPhysics(),
      ),
      children: widget.children,
    ),
  );
  if (widget.onRefresh == null) {
    return list;
  }
  if (widget.noSpinnerRefreshIndicator) {
    return RefreshIndicator.noSpinner(
      onRefresh: widget.onRefresh!,
      child: list,
    );
  }
  return RefreshIndicator(
    onRefresh: widget.onRefresh!,
    color: Theme.of(context).primaryColor,
    child: list,
  );
}
}
