import 'package:flutter/material.dart';

/// Full-screen tap-to-zoom viewer for a case photo, shared by the User and
/// Doctor apps' case detail screens.
void showPhotoViewer(BuildContext context, String url) {
  showDialog(
    context: context,
    barrierColor: Colors.black87,
    builder: (context) => GestureDetector(
      onTap: () => Navigator.pop(context),
      child: Scaffold(
        backgroundColor: Colors.transparent,
        body: SafeArea(
          child: Stack(
            children: [
              Center(
                child: InteractiveViewer(
                  child: Image.network(
                    url,
                    errorBuilder: (context, error, stack) =>
                        const Icon(Icons.broken_image_rounded, color: Colors.white54, size: 64),
                  ),
                ),
              ),
              Positioned(
                top: 8,
                right: 8,
                child: IconButton(
                  icon: const Icon(Icons.close_rounded, color: Colors.white),
                  onPressed: () => Navigator.pop(context),
                ),
              ),
            ],
          ),
        ),
      ),
    ),
  );
}
