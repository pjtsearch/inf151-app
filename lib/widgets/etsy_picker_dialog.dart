import 'package:flutter/material.dart';

import '../models/goal.dart';
import '../services/etsy_service.dart';

class EtsyPickerDialog extends StatefulWidget {
  const EtsyPickerDialog({super.key});
  @override
  State<EtsyPickerDialog> createState() => _EtsyPickerDialogState();
}

class _EtsyPickerDialogState extends State<EtsyPickerDialog> {
  final _controller = TextEditingController();
  final _scroll = ScrollController();
  final _service = EtsyService();
  final List<EtsyListing> _items = [];
  bool _loading = false, _more = false;
  String? _error;
  int _offset = 0;
  String _query = '';

  @override
  void initState() {
    super.initState();
    _scroll.addListener(_onScroll);
  }
  @override
  void dispose() { _controller.dispose(); _scroll.dispose(); super.dispose(); }

  void _onScroll() {
    if (_scroll.position.pixels > _scroll.position.maxScrollExtent - 500) _load();
  }

  Future<void> _search() async {
    _query = _controller.text.trim();
    if (_query.isEmpty) return;
    setState(() { _items.clear(); _offset = 0; _more = true; _error = null; });
    await _load();
  }

  Future<void> _load() async {
    if (_loading || !_more || _query.isEmpty) return;
    setState(() => _loading = true);
    try {
      final (items, more) = await _service.search(_query, _offset);
      if (!mounted) return;
      setState(() { _items.addAll(items); _offset += items.length; _more = more && items.isNotEmpty; });
    } catch (error) {
      if (mounted) setState(() => _error = error.toString());
    } finally { if (mounted) setState(() => _loading = false); }
  }

  @override
  Widget build(BuildContext context) => Dialog(
    child: SizedBox(
      width: 780, height: 650,
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Row(children: [Expanded(child: Text('Choose an Etsy product', style: Theme.of(context).textTheme.titleLarge)), IconButton(onPressed: () => Navigator.pop(context), icon: const Icon(Icons.close))]),
          const SizedBox(height: 12),
          TextField(controller: _controller, textInputAction: TextInputAction.search, onSubmitted: (_) => _search(), decoration: InputDecoration(hintText: 'Search Etsy', prefixIcon: const Icon(Icons.search), border: const OutlineInputBorder(), suffixIcon: IconButton(onPressed: _search, icon: const Icon(Icons.arrow_forward))),),
          const SizedBox(height: 14),
          Expanded(child: _error != null
              ? Center(child: Text(_error!, textAlign: TextAlign.center))
              : _items.isEmpty
                  ? Center(child: _loading ? const CircularProgressIndicator() : const Text('Search for a product to get started'))
                  : GridView.builder(
            controller: _scroll, gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(maxCrossAxisExtent: 240, mainAxisExtent: 310, crossAxisSpacing: 12, mainAxisSpacing: 12),
            itemCount: _items.length + (_loading ? 1 : 0),
            itemBuilder: (context, index) => index == _items.length ? const Center(child: CircularProgressIndicator()) : _ListingCard(listing: _items[index], onTap: () => Navigator.pop(context, EtsyProductReward(listingId: _items[index].id, title: _items[index].title, url: _items[index].url, price: _items[index].price))),
          )),
        ]),
      ),
    ),
  );
}

class _ListingCard extends StatefulWidget {
  const _ListingCard({required this.listing, required this.onTap});
  final EtsyListing listing;
  final VoidCallback onTap;
  @override
  State<_ListingCard> createState() => _ListingCardState();
}

class _ListingCardState extends State<_ListingCard> {
  String? _url;
  bool _requested = false;
  @override
  void didChangeDependencies() { super.didChangeDependencies(); _loadImage(); }
  Future<void> _loadImage() async {
    if (_requested) return;
    _requested = true;
    // GridView only builds visible and nearby children, so image endpoint calls stay lazy.
    try { final url = await EtsyService().imageUrl(widget.listing.id); if (mounted) setState(() => _url = url); } catch (_) { }
  }
  @override
  Widget build(BuildContext context) => Card(clipBehavior: Clip.antiAlias, child: InkWell(onTap: widget.onTap, child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
    SizedBox(height: 140, width: double.infinity, child: _url == null ? const ColoredBox(color: Color(0xFFEDEFEA), child: Center(child: Icon(Icons.image_outlined))) : Image.network(_url!, fit: BoxFit.cover, errorBuilder: (_, __, ___) => const Center(child: Icon(Icons.broken_image_outlined)))),
    Padding(padding: const EdgeInsets.all(10), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(widget.listing.title, maxLines: 2, overflow: TextOverflow.ellipsis, style: Theme.of(context).textTheme.titleSmall),
      const SizedBox(height: 4), Text(widget.listing.description, maxLines: 2, overflow: TextOverflow.ellipsis, style: Theme.of(context).textTheme.bodySmall),
      const SizedBox(height: 6), Text(widget.listing.price.isEmpty ? '' : '\$${widget.listing.price}', style: Theme.of(context).textTheme.labelLarge),
    ])),
  ])));
}
