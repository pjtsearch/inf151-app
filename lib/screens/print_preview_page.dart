import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:pdf/pdf.dart';
import 'package:printing/printing.dart';

import '../services/punch_card_pdf.dart';

enum _PaperSize {
  letter('Letter (8.5 × 11 in)', PdfPageFormat.letter),
  a4('A4 (210 × 297 mm)', PdfPageFormat.a4),
  legal('Legal (8.5 × 14 in)', PdfPageFormat.legal),
  a5('A5 (148 × 210 mm)', PdfPageFormat.a5);

  const _PaperSize(this.label, this.format);

  final String label;
  final PdfPageFormat format;
}

class PrintPreviewPage extends StatefulWidget {
  const PrintPreviewPage({super.key, required this.jobs})
    : assert(jobs.length > 0);

  final List<PunchCardPrintJob> jobs;

  @override
  State<PrintPreviewPage> createState() => _PrintPreviewPageState();
}

class _PrintPreviewPageState extends State<PrintPreviewPage> {
  _PaperSize _paperSize = _PaperSize.letter;
  late Future<Uint8List> _document;
  bool _printing = false;

  @override
  void initState() {
    super.initState();
    _document = _buildDocument();
  }

  Future<Uint8List> _buildDocument() =>
      buildPunchCardsPdf(widget.jobs, pageFormat: _paperSize.format);

  Future<void> _print(Uint8List bytes) async {
    if (_printing) return;
    setState(() => _printing = true);
    try {
      await Printing.layoutPdf(
        onLayout: (_) => bytes,
        format: _paperSize.format,
        dynamicLayout: false,
        name: widget.jobs.length == 1
            ? '${widget.jobs.single.goal.title.replaceAll(RegExp(r'[^a-zA-Z0-9-_]'), '_')}_punch_card.pdf'
            : 'goal_punch_cards.pdf',
      );
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not print. Please try again.')),
      );
    } finally {
      if (mounted) setState(() => _printing = false);
    }
  }

  Widget _preview(AsyncSnapshot<Uint8List> snapshot) {
    if (snapshot.connectionState != ConnectionState.done) {
      return const Center(child: CircularProgressIndicator());
    }
    if (snapshot.hasError) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('Could not create the preview.'),
            TextButton(
              onPressed: () => setState(() {
                _document = _buildDocument();
              }),
              child: const Text('Try again'),
            ),
          ],
        ),
      );
    }
    final bytes = snapshot.requireData;
    return PdfPreviewCustom(
      key: ValueKey(_paperSize),
      pageFormat: _paperSize.format,
      build: (_) => bytes,
      maxPageWidth: 700,
      scrollViewDecoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainer,
      ),
      onError: (_, _) =>
          const Center(child: Text('Could not display the preview.')),
    );
  }

  @override
  Widget build(BuildContext context) => FutureBuilder<Uint8List>(
    future: _document,
    builder: (context, snapshot) => Scaffold(
      appBar: AppBar(title: const Text('Print preview')),
      body: SafeArea(
        bottom: false,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.all(16),
              child: DropdownButtonFormField<_PaperSize>(
                initialValue: _paperSize,
                isExpanded: true,
                decoration: const InputDecoration(
                  labelText: 'Paper size',
                  border: OutlineInputBorder(),
                  helperText: 'Cards stay credit-card size.',
                ),
                items: [
                  for (final size in _PaperSize.values)
                    DropdownMenuItem(value: size, child: Text(size.label)),
                ],
                onChanged: _printing
                    ? null
                    : (size) {
                        if (size == null || size == _paperSize) return;
                        setState(() {
                          _paperSize = size;
                          _document = _buildDocument();
                        });
                      },
              ),
            ),
            Expanded(child: _preview(snapshot)),
          ],
        ),
      ),
      bottomNavigationBar: SafeArea(
        top: false,
        minimum: const EdgeInsets.all(16),
        child: FilledButton.icon(
          onPressed:
              _printing ||
                  snapshot.connectionState != ConnectionState.done ||
                  !snapshot.hasData
              ? null
              : () => _print(snapshot.requireData),
          icon: const Icon(Icons.print_outlined),
          label: Text(_printing ? 'Printing…' : 'Print'),
        ),
      ),
    ),
  );
}
