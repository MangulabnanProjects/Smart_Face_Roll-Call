import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:intl/intl.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'dart:io';

/// Enhanced gallery with date filtering and user-specific images
class GalleryScreen extends StatefulWidget {
  const GalleryScreen({super.key});

  @override
  State<GalleryScreen> createState() => _GalleryScreenState();
}

class _GalleryScreenState extends State<GalleryScreen> {
  List<FileSystemEntity> allImages = [];
  List<FileSystemEntity> filteredImages = [];
  String selectedFilter = 'All';
  bool isLoading = true;
  bool _shouldRefresh = false;

  @override
  void initState() {
    super.initState();
    _loadImages();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Only refresh if flag is set (after taking a photo)
    if (_shouldRefresh && !isLoading) {
      _shouldRefresh = false;
      _loadImages();
    }
  }

  void markForRefresh() {
    _shouldRefresh = true;
  }

  Future<void> _loadImages() async {
    setState(() => isLoading = true);
    
    try {
      final currentUser = FirebaseAuth.instance.currentUser;
      if (currentUser == null) {
        setState(() => isLoading = false);
        return;
      }

      final directory = await getApplicationDocumentsDirectory();
      // User-specific image directory
      final imagesPath = Directory('${directory.path}/images/${currentUser.uid}');
      
      if (await imagesPath.exists()) {
        final files = imagesPath
            .listSync()
            .where((item) => item.path.endsWith('.jpg'))
            .toList();
        
        files.sort((a, b) => b.statSync().modified.compareTo(a.statSync().modified));
        
        setState(() {
          allImages = files;
          filteredImages = files;
          isLoading = false;
        });
      } else {
        setState(() => isLoading = false);
      }
    } catch (e) {
      setState(() => isLoading = false);
    }
  }

  void _filterByDate(String filter) {
    setState(() {
      selectedFilter = filter;
      final now = DateTime.now();
      
      if (filter == 'All') {
        filteredImages = allImages;
      } else if (filter == 'Today') {
        filteredImages = allImages.where((file) {
          final modified = file.statSync().modified;
          return modified.year == now.year &&
                 modified.month == now.month &&
                 modified.day == now.day;
        }).toList();
      } else if (filter == 'Yesterday') {
        final yesterday = now.subtract(const Duration(days: 1));
        filteredImages = allImages.where((file) {
          final modified = file.statSync().modified;
          return modified.year == yesterday.year &&
                 modified.month == yesterday.month &&
                 modified.day == yesterday.day;
        }).toList();
      } else if (filter == 'This Week') {
        final weekAgo = now.subtract(const Duration(days: 7));
        filteredImages = allImages.where((file) {
          return file.statSync().modified.isAfter(weekAgo);
        }).toList();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Gallery (${filteredImages.length})'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () {
              setState(() => isLoading = true);
              _loadImages();
            },
          ),
        ],
      ),
      body: Column(
        children: [
          // Filter chips
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  _buildFilterChip('All'),
                  const SizedBox(width: 8),
                  _buildFilterChip('Today'),
                  const SizedBox(width: 8),
                  _buildFilterChip('Yesterday'),
                  const SizedBox(width: 8),
                  _buildFilterChip('This Week'),
                ],
              ),
            ),
          ),

          // Image grid
          Expanded(
            child: isLoading
                ? const Center(child: CircularProgressIndicator())
                : filteredImages.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.photo_library, size: 64, color: Colors.grey.shade400),
                            const SizedBox(height: 16),
                            const Text('No photos found'),
                          ],
                        ),
                      )
                    : GridView.builder(
                        padding: const EdgeInsets.all(8),
                        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 3,
                          crossAxisSpacing: 4,
                          mainAxisSpacing: 4,
                        ),
                        itemCount: filteredImages.length,
                        itemBuilder: (context, index) {
                          return GestureDetector(
                            onTap: () => _showImage(filteredImages[index]),
                            child: Image.file(
                              File(filteredImages[index].path),
                              fit: BoxFit.cover,
                            ),
                          );
                        },
                      ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterChip(String label) {
    final isSelected = selectedFilter == label;
    return FilterChip(
      label: Text(label),
      selected: isSelected,
      onSelected: (selected) => _filterByDate(label),
      selectedColor: Colors.blue,
      checkmarkColor: Colors.white,
      labelStyle: TextStyle(
        color: isSelected ? Colors.white : Colors.black87,
        fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
        fontSize: 12,
      ),
    );
  }

  void _showImage(FileSystemEntity file) {
    final modified = file.statSync().modified;
    final formattedDate = DateFormat('EEEE, MMM d, y \'at\' HH:mm:ss').format(modified);
    
    showDialog(
      context: context,
      builder: (context) => Dialog(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Image.file(File(file.path)),
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  Text(formattedDate, style: const TextStyle(fontSize: 14)),
                  const SizedBox(height: 16),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      TextButton.icon(
                        onPressed: () async {
                          Navigator.pop(context);
                          await file.delete();
                          _loadImages();
                        },
                        icon: const Icon(Icons.delete, color: Colors.red),
                        label: const Text('Delete', style: TextStyle(color: Colors.red)),
                      ),
                      TextButton(
                        onPressed: () => Navigator.pop(context),
                        child: const Text('Close'),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
