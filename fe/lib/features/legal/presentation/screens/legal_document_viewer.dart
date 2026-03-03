import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:barz/core/design/design_system.dart';
import 'package:barz/core/utils/injections.dart';
import 'package:barz/features/legal/data/legal_repository.dart';
import 'package:barz/features/legal/domain/models/legal_document.dart';

class LegalDocumentViewer extends StatefulWidget {
  final LegalDocumentType documentType;
  final LegalDocumentLanguage? initialLanguage;

  const LegalDocumentViewer({
    super.key,
    required this.documentType,
    this.initialLanguage,
  });

  @override
  State<LegalDocumentViewer> createState() => _LegalDocumentViewerState();
}

class _LegalDocumentViewerState extends State<LegalDocumentViewer> {
  late LegalDocumentLanguage _selectedLanguage;
  late final LegalRepository _repository;
  LegalDocument? _document;
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _repository = getItInjector<LegalRepository>();
    _selectedLanguage =
        widget.initialLanguage ??
        LegalDocumentLanguage.fromLocale(Platform.localeName);
    _loadDocument();
  }

  Future<void> _loadDocument() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final document = await _repository.getLegalDocument(
        widget.documentType,
        _selectedLanguage,
      );
      if (mounted) {
        setState(() {
          _document = document;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = e.toString();
          _isLoading = false;
        });
      }
    }
  }

  void _changeLanguage(LegalDocumentLanguage language) {
    if (language != _selectedLanguage) {
      setState(() {
        _selectedLanguage = language;
      });
      _loadDocument();
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = context.dobarColors;

    return Scaffold(
      backgroundColor: theme.brightness == Brightness.light
          ? Colors.white
          : colors.background,
      appBar: AppBar(
        title: Text(widget.documentType.displayName),
        backgroundColor: theme.brightness == Brightness.light
            ? Colors.white
            : colors.surface,
        foregroundColor: colors.labelPrimary,
        elevation: 0,
        actions: [
          PopupMenuButton<LegalDocumentLanguage>(
            icon: Icon(Icons.language, color: colors.labelPrimary),
            onSelected: _changeLanguage,
            itemBuilder: (context) => LegalDocumentLanguage.values
                .map(
                  (lang) => PopupMenuItem(
                    value: lang,
                    child: Row(
                      children: [
                        if (lang == _selectedLanguage)
                          Icon(
                            Icons.check,
                            color: colors.buttonPrimary,
                            size: 20,
                          )
                        else
                          const SizedBox(width: 20),
                        const SizedBox(width: 8),
                        Text(lang.displayName),
                      ],
                    ),
                  ),
                )
                .toList(),
          ),
        ],
      ),
      body: _buildBody(colors),
    );
  }

  Widget _buildBody(DobarColors colors) {
    if (_isLoading) {
      return Center(
        child: CircularProgressIndicator(color: colors.buttonPrimary),
      );
    }

    if (_error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(BarzSpacing.xl),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.error_outline, size: 64, color: colors.labelSecondary),
              const SizedBox(height: BarzSpacing.md),
              Text(
                'Failed to load document',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: colors.labelPrimary,
                ),
              ),
              const SizedBox(height: BarzSpacing.sm),
              Text(
                _error!,
                style: TextStyle(color: colors.labelSecondary),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: BarzSpacing.lg),
              ElevatedButton(
                onPressed: _loadDocument,
                style: ElevatedButton.styleFrom(
                  backgroundColor: colors.buttonPrimary,
                  foregroundColor: textOnDark,
                ),
                child: const Text('Retry'),
              ),
            ],
          ),
        ),
      );
    }

    if (_document == null) {
      return const Center(child: Text('No document loaded'));
    }

    return Markdown(
      data: _document!.content,
      selectable: true,
      styleSheet: MarkdownStyleSheet(
        p: TextStyle(fontSize: 14, height: 1.6, color: colors.labelPrimary),
        h1: TextStyle(
          fontSize: 24,
          fontWeight: FontWeight.bold,
          color: colors.labelPrimary,
        ),
        h2: TextStyle(
          fontSize: 20,
          fontWeight: FontWeight.bold,
          color: colors.labelPrimary,
        ),
        h3: TextStyle(
          fontSize: 18,
          fontWeight: FontWeight.bold,
          color: colors.labelPrimary,
        ),
        listBullet: TextStyle(color: colors.labelPrimary),
      ),
      padding: const EdgeInsets.all(BarzSpacing.lg),
    );
  }
}
