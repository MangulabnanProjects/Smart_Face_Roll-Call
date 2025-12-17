import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:intl/intl.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'dart:io';
import '../../shared/services/image_service.dart';

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
    // Listen for global image updates
    ImageService().onImageSaved.addListener(_handleImageSaved);
  }

  @override
  void dispose() {
    ImageService().onImageSaved.removeListener(_handleImageSaved);
    super.dispose();
  }

  void _handleImageSaved() {
    if (mounted) {
      _loadImages();
    }
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
            .where((item) => item.path.endsWith('.jpg') && !item.path.contains('_labeled'))
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

  void _showImage(FileSystemEntity file) async {
    // 1. Check for labeled version
    final path = file.path;
    final dir = file.parent;
    final fileName = path.split(Platform.pathSeparator).last;
    final extension = fileName.split('.').last;
    final labeledName = fileName.replaceAll('.$extension', '_labeled.$extension');
    final labeledFile = File('${dir.path}/$labeledName');
    
    bool hasLabeled = await labeledFile.exists();

    final modified = file.statSync().modified;
    final formattedDate = DateFormat('EEEE, MMM d, y \'at\' HH:mm:ss').format(modified);
    
    if (!mounted) return;

    showDialog(
      context: context,
      builder: (context) => Dialog(
        insetPadding: const EdgeInsets.all(16),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Padding(
                padding: EdgeInsets.all(16.0),
                child: Text("Detection Details", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
              ),
              
              if (hasLabeled) ...[
                 const Padding(
                   padding: EdgeInsets.only(bottom: 8.0),
                   child: Text("Labeled (AI)", style: TextStyle(color: Colors.blue, fontWeight: FontWeight.bold)),
                 ),
                 Image.file(labeledFile),
                 const SizedBox(height: 16),
                 const Divider(),
                 const SizedBox(height: 16),
              ],
              
              const Padding(
                 padding: EdgeInsets.only(bottom: 8.0),
                 child: Text("Original", style: TextStyle(fontWeight: FontWeight.bold)),
              ),
              Image.file(File(file.path)),
              
              Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: [
                    Text(formattedDate, style: const TextStyle(fontSize: 14, color: Colors.grey)),
                    const SizedBox(height: 16),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: [
                        TextButton.icon(
                          onPressed: () async {
                            // Confirm deletion
                            final confirm = await showDialog<bool>(
                              context: context,
                              builder: (ctx) => AlertDialog(
                                title: const Text('Delete Image?'),
                                content: const Text(
                                  'This will delete the image (and its labeled version) from the app and your phone gallery. This cannot be undone.',
                                ),
                                actions: [
                                  TextButton(
                                    onPressed: () => Navigator.pop(ctx, false),
                                    child: const Text('Cancel'),
                                  ),
                                  TextButton(
                                    onPressed: () => Navigator.pop(ctx, true),
                                    style: TextButton.styleFrom(foregroundColor: Colors.red),
                                    child: const Text('Delete'),
                                  ),
                                ],
                              ),
                            );

                            if (confirm == true) {
                              try {
                                final directory = await getApplicationDocumentsDirectory();
                                
                                // Paths
                                final sharedPath = '${directory.path}/images/shared/$fileName';
                                final sharedLabeledPath = '${directory.path}/images/shared/$labeledName';
                                final dcimPath = '/storage/emulated/0/DCIM/SmartAttendance/$fileName';

                                // 2. Delete from User Gallery (Private)
                                await file.delete();
                                if (await labeledFile.exists()) {
                                  await labeledFile.delete();
                                }

                                // 3. Delete from Shared/Recents (Global)
                                final sharedFile = File(sharedPath);
                                if (await sharedFile.exists()) await sharedFile.delete();
                                
                                final sharedLabeled = File(sharedLabeledPath);
                                if (await sharedLabeled.exists()) await sharedLabeled.delete();

                                // 4. Delete from Phone Gallery (DCIM)
                                final dcimFile = File(dcimPath);
                                if (await dcimFile.exists()) await dcimFile.delete();

                                // 5. Notify Global Listeners
                                ImageService().notifyImageSaved();

                                if (context.mounted) {
                                  Navigator.pop(context); // Close Image Dialog
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(content: Text('Images deleted')),
                                  );
                                }
                              } catch (e) {
                                debugPrint('Error deleting: $e');
                                if (context.mounted) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(content: Text('Error deleting: $e')),
                                  );
                                }
                              }
                            }
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
      ),
    );
  }
}
