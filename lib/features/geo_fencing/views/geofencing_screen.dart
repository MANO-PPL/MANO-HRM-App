import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import '../../../../shared/widgets/glass_container.dart';
import '../../../../shared/widgets/toast_helper.dart';
import '../../../../shared/widgets/glass_success_dialog.dart';
import '../../../../shared/constants/api_constants.dart';
import '../models/location_model.dart';
import '../services/location_service.dart';
import '../../../../shared/widgets/loading_screen.dart';

String? _resolveAvatarUrl(dynamic profileImage) {
  if (profileImage == null || profileImage.toString().isEmpty) return null;
  final url = profileImage.toString();
  if (url.startsWith('http')) return url;
  // Remove leading slash if present to avoid double slashes
  final cleanUrl = url.startsWith('/') ? url : '/$url';
  return '${ApiConstants.baseUrl}$cleanUrl';
}

class GeofencingScreen extends StatefulWidget {
  final LocationService locationService;
  const GeofencingScreen({super.key, required this.locationService});

  @override
  State<GeofencingScreen> createState() => _GeofencingScreenState();
}

class _GeofencingScreenState extends State<GeofencingScreen> {
  // Map Configurations
  static const Map<String, Map<String, String>> _mapThemes = {
    'dark':    {'name': 'Night Mode',  'url': 'https://{s}.basemaps.cartocdn.com/dark_all/{z}/{x}/{y}{r}.png'},
    'light':   {'name': 'Light Mode',  'url': 'https://{s}.basemaps.cartocdn.com/light_all/{z}/{x}/{y}{r}.png'},
    'voyager': {'name': 'Day Mode',    'url': 'https://{s}.basemaps.cartocdn.com/rastertiles/voyager/{z}/{x}/{y}{r}.png'},
    'satellite':{'name': 'Satellite',  'url': 'https://server.arcgisonline.com/ArcGIS/rest/services/World_Imagery/MapServer/tile/{z}/{y}/{x}'},
    'streets': {'name': 'Streets',     'url': 'https://tile.openstreetmap.org/{z}/{x}/{y}.png'},
  };

  String _activeMapTheme = 'voyager';
  bool _isMapThemeMenuOpen = false;
  final MapController _mapController = MapController();

  // Locations State
  List<WorkLocation> _locations = [];
  WorkLocation? _selectedLocation;
  double _currentRadius = 100.0;
  bool _isLoading = true;

  // Users State
  List<Map<String, dynamic>> _users = [];
  bool _isLoadingUsers = true;

  @override
  void initState() {
    super.initState();
    _fetchLocations();
    _fetchUsers();
  }

  // --- API FETCHING ---

  Future<void> _fetchLocations() async {
    try {
      final data = await widget.locationService.getLocations();
      if (mounted) {
        setState(() {
          _locations = data;
          _isLoading = false;
          // Select first if none selected
          if (data.isNotEmpty && _selectedLocation == null) {
            _selectLocation(data.first);
          } else if (_selectedLocation != null) {
             // Refresh selected object
             final updated = data.firstWhere((l) => l.id == _selectedLocation!.id, orElse: () => data.first);
             _selectLocation(updated);
          }
        });
      }
    } catch (e) {
      debugPrint(e.toString());
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _fetchUsers() async {
    try {
      final users = await widget.locationService.getUsersWithLocations();
      debugPrint("Fetched ${users.length} users");
      // Debug first user structure
      if (users.isNotEmpty) {
        debugPrint("User 0: ${users.first}");
      }
      if (mounted) {
        setState(() {
          _users = users;
          _isLoadingUsers = false;
        });
      }
    } catch (e) {
      debugPrint("Failed to fetch users: $e");
      if (mounted) setState(() => _isLoadingUsers = false);
    }
  }

  // --- ACTIONS ---

  void _selectLocation(WorkLocation loc) {
    setState(() {
      _selectedLocation = loc;
      _currentRadius = loc.radius.toDouble();
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        try {
          _mapController.move(
            LatLng(loc.latitude.toDouble(), loc.longitude.toDouble()),
            15.0,
          );
        } catch (_) {}
      }
    });
  }

  void _updateRadius(double newRadius) {
     if (_selectedLocation == null) return;
     
     // Optimistic UI Update not easily possible for immutable object without deep copy/copyWith
     // We will just call API and refresh.
     // To make slider smooth, we might need local state for slider value if we wanted "live" sliding.
     // But `onChangeEnd` is safe.

     widget.locationService.updateLocation(_selectedLocation!.id, {"radius": newRadius.toInt()}).then((_) {
         _fetchLocations(); 
     });
  }

  Future<void> _toggleActiveStatus() async {
    if (_selectedLocation == null) return;
    final newStatus = !_selectedLocation!.isActive;
    
    try {
      await widget.locationService.updateLocation(_selectedLocation!.id, {"is_active": newStatus ? 1 : 0});
      _fetchLocations();
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Update failed: $e")));
    }
  }



  Future<void> _toggleUserAssignment(int userId, String userName, bool isAssigned) async {
      if (_selectedLocation == null) return;
      
      final isAdding = !isAssigned;
      final targetLocId = _selectedLocation!.id;

      // 1. Optimistic UI Update: Toggle assignment locally
      setState(() {
        final userIndex = _users.indexWhere((u) => u['user_id'] == userId);
        if (userIndex != -1) {
          final userCopy = Map<String, dynamic>.from(_users[userIndex]);
          final List<dynamic> currentLocs = List<dynamic>.from(userCopy['work_locations'] ?? []);
          
          if (isAdding) {
            currentLocs.add({
              'location_id': targetLocId,
              'loc_id': targetLocId,
            });
          } else {
            currentLocs.removeWhere((l) =>
                l is Map && (l['location_id'] == targetLocId || l['loc_id'] == targetLocId));
          }
          userCopy['work_locations'] = currentLocs;
          _users[userIndex] = userCopy;
        }
      });

      // 2. Real-time Toast
      if (mounted) {
        context.showToast(
          isAdding ? "Assigning $userName..." : "Removing $userName...",
          isSuccess: true,
        );
      }

      // 3. Perform Action in Background
      try {
        await widget.locationService.assignUser(targetLocId, userId, isAdding);
        _fetchUsers(); // Keep final state fully synced with server

        if (!mounted) return;

        // Final Toast
        context.showToast(
          isAdding ? "$userName assigned successfully" : "$userName removed successfully",
          isSuccess: true,
        );

      } catch (e) {
        // Revert UI Update on Failure
        if (mounted) {
          setState(() {
            final userIndex = _users.indexWhere((u) => u['user_id'] == userId);
            if (userIndex != -1) {
              final userCopy = Map<String, dynamic>.from(_users[userIndex]);
              final List<dynamic> currentLocs = List<dynamic>.from(userCopy['work_locations'] ?? []);
              
              if (isAdding) {
                currentLocs.removeWhere((l) =>
                    l is Map && (l['location_id'] == targetLocId || l['loc_id'] == targetLocId));
              } else {
                currentLocs.add({
                  'location_id': targetLocId,
                  'loc_id': targetLocId,
                });
              }
              userCopy['work_locations'] = currentLocs;
              _users[userIndex] = userCopy;
            }
          });
          context.showToast("Assignment failed: $e", isError: true);
        }
      }
  }

  void _showCreateDialog() {
    showDialog(
      context: context,
      builder: (ctx) => _LocationFormDialog(
        onSubmit: (data) async {
          try {
            await widget.locationService.createLocation(data);
            if (!ctx.mounted) return;
            Navigator.pop(ctx);
            _fetchLocations();
            if (!mounted) return;
            
            // Success Dialog
            showDialog(
              context: context,
              barrierDismissible: false,
              builder: (context) => GlassSuccessDialog(
                title: "Location Created",
                message: "New geofence location has been successfully created.",
                onDismiss: () => Navigator.pop(context),
              ),
            );
          } catch (e) {
            if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Error: $e")));
          }
        },
      ),
    );
  }

  // --- LAYOUT BUILDERS ---

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: LoadingScreen(
        isLoading: _isLoading || _isLoadingUsers,
        message: "Loading locations...",
        child: OrientationBuilder(
          builder: (context, orientation) {
            if (orientation == Orientation.landscape) {
              return _buildDesktopLayout();
            }
            return _buildMobileLayout();
          },
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _showCreateDialog,
        backgroundColor: Colors.indigo,
        child: const Icon(Icons.add, color: Colors.white),
      ),
    );
  }

  Widget _buildDesktopLayout() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // 1. LEFT PANEL: Locations List (320px)
          SizedBox(
            width: 320,
            child: GlassContainer(
              color: isDark ? const Color(0xFF161B22) : Colors.white,
              borderRadius: 12,
              padding: EdgeInsets.zero,
              child: Column(
                children: [
                   _buildListHeader(),
                   const Divider(height: 1),
                   Expanded(child: _buildLocationList()),
                ],
              ),
            ),
          ),
          
          const SizedBox(width: 16),
          
          // 2. CENTER PANEL: Location Details (Flexible)
          Expanded(
            flex: 2,
            child: GlassContainer(
               color: isDark ? const Color(0xFF161B22) : Colors.white,
               borderRadius: 12,
               padding: const EdgeInsets.all(24),
               child: _selectedLocation == null 
                  ? const Center(child: Text("Select a location to edit", style: TextStyle(color: Colors.grey)))
                  : _buildLocationSettingsPanel(isDark),
            ),
          ),
          
          const SizedBox(width: 16),
          
          // 3. RIGHT PANEL: Assigned Staff (320px)
          SizedBox(
            width: 320,
            child: GlassContainer(
              color: isDark ? const Color(0xFF161B22) : Colors.white,
              borderRadius: 12,
              padding: EdgeInsets.zero,
              child: Column(
                children: [
                   Padding(
                     padding: const EdgeInsets.all(16),
                     child: Row(
                       mainAxisAlignment: MainAxisAlignment.spaceBetween,
                       children: [
                         Row(
                           children: [
                             const Icon(Icons.people_outline, size: 20),
                             const SizedBox(width: 8),
                             Text(
                               "Assigned Staff",
                               style: TextStyle(
                                 fontWeight: FontWeight.bold,
                                 fontSize: 16,
                                 color: isDark ? Colors.white : Colors.black87,
                               ),
                             ),
                           ],
                         ),
                         if (_selectedLocation != null)
                           IconButton(
                             icon: const Icon(Icons.person_add_alt_1_outlined, color: Colors.indigo, size: 20),
                             tooltip: "Assign Staff",
                             onPressed: () => _showAssignStaffDialog(context, _selectedLocation!),
                           ),
                       ],
                     ),
                   ),
                   const Divider(height: 1),
                   Expanded(child: _buildStaffList()),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLocationSettingsPanel(bool isDark) {
    final centerLatLng = LatLng(
      _selectedLocation!.latitude.toDouble(),
      _selectedLocation!.longitude.toDouble(),
    );
    final tileUrl = _mapThemes[_activeMapTheme]!['url']!;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // 1. HEADER: Location Name & Active Status Switch
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _selectedLocation!.name,
                    style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                      color: isDark ? Colors.white : Colors.black87,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    _selectedLocation!.address,
                    style: const TextStyle(color: Colors.grey, fontSize: 13),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Switch(
              value: _selectedLocation!.isActive,
              onChanged: (_) => _toggleActiveStatus(),
              activeTrackColor: Colors.indigo,
            ),
          ],
        ),
        const SizedBox(height: 16),

        // 2. CENTER: Leaflet Map View
        Expanded(
          child: ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: Stack(
              children: [
                FlutterMap(
                  mapController: _mapController,
                  options: MapOptions(
                    initialCenter: centerLatLng,
                    initialZoom: 15.0,
                    onTap: (_, _) {
                      setState(() {
                        _isMapThemeMenuOpen = false;
                      });
                    },
                  ),
                  children: [
                    TileLayer(
                      urlTemplate: tileUrl,
                      subdomains: _activeMapTheme == 'satellite' ? const [] : const ['a', 'b', 'c'],
                      userAgentPackageName: 'co.mano.attendance',
                      retinaMode: RetinaMode.isHighDensity(context),
                    ),
                    CircleLayer(
                      circles: [
                        CircleMarker(
                          point: centerLatLng,
                          radius: _currentRadius,
                          useRadiusInMeter: true,
                          color: Colors.indigo.withValues(alpha: 0.15),
                          borderColor: Colors.indigo,
                          borderStrokeWidth: 2,
                        ),
                      ],
                    ),
                    MarkerLayer(
                      markers: [
                        Marker(
                          point: centerLatLng,
                          width: 40,
                          height: 40,
                          child: const Icon(
                            Icons.location_on,
                            color: Colors.red,
                            size: 40,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),

                // Map Theme Button Overlay
                Positioned(
                  top: 10,
                  right: 10,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      ElevatedButton.icon(
                        onPressed: () {
                          setState(() {
                            _isMapThemeMenuOpen = !_isMapThemeMenuOpen;
                          });
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: isDark ? const Color(0xFF1F2937) : Colors.white,
                          foregroundColor: isDark ? Colors.white : Colors.black87,
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                          elevation: 4,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                        ),
                        icon: const Icon(Icons.layers_outlined, size: 16),
                        label: Text(
                          _mapThemes[_activeMapTheme]!['name']!,
                          style: GoogleFonts.poppins(fontSize: 11, fontWeight: FontWeight.w600),
                        ),
                      ),
                      if (_isMapThemeMenuOpen) ...[
                        const SizedBox(height: 4),
                        Container(
                          width: 140,
                          decoration: BoxDecoration(
                            color: isDark ? const Color(0xFF1F2937) : Colors.white,
                            borderRadius: BorderRadius.circular(8),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withValues(alpha: 0.15),
                                blurRadius: 8,
                                offset: const Offset(0, 4),
                              ),
                            ],
                          ),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: _mapThemes.entries.map((e) {
                              final isSelected = _activeMapTheme == e.key;
                              return InkWell(
                                onTap: () {
                                  setState(() {
                                    _activeMapTheme = e.key;
                                    _isMapThemeMenuOpen = false;
                                  });
                                },
                                child: Container(
                                  width: double.infinity,
                                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                  decoration: BoxDecoration(
                                    color: isSelected
                                        ? Colors.indigo.withValues(alpha: 0.1)
                                        : Colors.transparent,
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Text(
                                    e.value['name']!,
                                    style: GoogleFonts.poppins(
                                      fontSize: 11,
                                      fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                                      color: isSelected
                                          ? Colors.indigo
                                          : (isDark ? Colors.white70 : Colors.black87),
                                    ),
                                  ),
                                ),
                              );
                            }).toList(),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),

        // 3. BOTTOM: Geofence Slider & Coordinates Info Cards
        Text(
          "Geofence Radius",
          style: TextStyle(
            fontWeight: FontWeight.w600,
            fontSize: 13,
            color: isDark ? Colors.white70 : Colors.black54,
          ),
        ),
        const SizedBox(height: 4),
        Row(
          children: [
            Expanded(
              child: SliderTheme(
                data: SliderTheme.of(context).copyWith(
                  trackHeight: 6,
                  activeTrackColor: Colors.indigo,
                  thumbColor: Colors.indigo,
                  overlayColor: Colors.indigo.withValues(alpha: 0.2),
                ),
                child: Slider(
                  value: _currentRadius.clamp(0, 2000),
                  min: 0,
                  max: 2000,
                  onChanged: (val) {
                    setState(() => _currentRadius = val);
                  },
                  onChangeEnd: (val) => _updateRadius(val),
                ),
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: Colors.indigo.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                "${_currentRadius.toInt()} m",
                style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.indigo, fontSize: 13),
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),

        // Coordinates Cards (Read Only)
        Row(
          children: [
            Expanded(
              child: _buildInfoCard(isDark, "Latitude", _selectedLocation!.latitude.toString()),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: _buildInfoCard(isDark, "Longitude", _selectedLocation!.longitude.toString()),
            ),
          ],
        ),
      ],
    );
  }


  
  Widget _buildInfoCard(bool isDark, String label, String value) {
     return Container(
       padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
       decoration: BoxDecoration(
         color: isDark ? const Color(0xFF0D1117) : Colors.grey[50],
         borderRadius: BorderRadius.circular(12),
         border: Border.all(color: isDark ? Colors.white10 : Colors.grey[200]!)
       ),
       child: Column(
         crossAxisAlignment: CrossAxisAlignment.start,
         children: [
            Text(label, style: const TextStyle(fontSize: 11, color: Colors.grey)),
            const SizedBox(height: 2),
            Text(value, style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: isDark ? Colors.white : Colors.black87)),
         ],
       ),
     );
  }

  Widget _buildMobileLayout() {
     return _buildLocationList(isMobile: true);
  }

  // --- SUB-WIDGETS ---

  Widget _buildListHeader() {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
           const Text("Locations", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
           const SizedBox(height: 10),
           TextField(
             decoration: InputDecoration(
               hintText: "Search offices...",
               prefixIcon: const Icon(Icons.search, size: 18),
               filled: true,
               fillColor: Theme.of(context).brightness == Brightness.dark ? Colors.white10 : Colors.grey[100],
               border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide.none),
               contentPadding: const EdgeInsets.symmetric(vertical: 8)
             ),
           )
        ],
      ),
    );
  }

  Widget _buildLocationList({bool isMobile = false}) {
     if (_isLoading) return const SizedBox.shrink();
     
     return ListView.separated(
       padding: const EdgeInsets.all(12),
       itemCount: _locations.length,
       separatorBuilder: (context, index) => const SizedBox(height: 8),
       itemBuilder: (context, index) {
         final loc = _locations[index];
         final isSelected = loc.id == _selectedLocation?.id;
         final isDark = Theme.of(context).brightness == Brightness.dark;
         
         // Count active users
         final activeUsers = _users.where((u) {
            final List<dynamic>? userLocs = u['work_locations'];
            if (userLocs == null) return false;
            return userLocs.any((l) => l is Map && (l['location_id'] == loc.id || l['loc_id'] == loc.id));
         }).length;

         return InkWell(
           onTap: () {
              _selectLocation(loc);
              if (isMobile) {
                _showMobileDetailSheet(loc);
              }
           },
           child: Container(
             padding: const EdgeInsets.all(12),
             decoration: BoxDecoration(
               color: isSelected && !isMobile
                  ? (isDark ? Colors.indigo.withValues(alpha: 0.2) : Colors.indigo[50])
                  : (isDark ? const Color(0xFF161B22) : Colors.white),
               borderRadius: BorderRadius.circular(8),
               border: isSelected && !isMobile ? Border.all(color: Colors.indigo.withValues(alpha: 0.5)) : null,
             ),
             child: Column(
               crossAxisAlignment: CrossAxisAlignment.start,
               children: [
                 Row(
                   mainAxisAlignment: MainAxisAlignment.spaceBetween,
                   children: [
                     Expanded(
                       child: Text(
                         loc.name,
                         style: TextStyle(
                           fontWeight: FontWeight.bold,
                           color: isSelected && !isMobile ? Colors.indigo : null,
                         ),
                         overflow: TextOverflow.ellipsis,
                       ),
                     ),
                     const SizedBox(width: 8),
                     Container(
                       width: 8, height: 8,
                       decoration: BoxDecoration(
                         color: loc.isActive ? Colors.green : Colors.grey,
                         shape: BoxShape.circle,
                       ),
                     )
                   ],
                 ),
                 const SizedBox(height: 4),
                 Row(
                   mainAxisAlignment: MainAxisAlignment.spaceBetween,
                   children: [
                     Expanded(
                       child: Text(
                         loc.address,
                         style: const TextStyle(fontSize: 11, color: Colors.grey),
                         maxLines: 1,
                         overflow: TextOverflow.ellipsis,
                       ),
                     ),
                     const SizedBox(width: 8),
                     Container(
                       padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                       decoration: BoxDecoration(
                         color: isSelected && !isMobile
                             ? Colors.indigo.withValues(alpha: 0.15)
                             : (isDark ? Colors.white10 : Colors.grey[100]),
                         borderRadius: BorderRadius.circular(10),
                       ),
                       child: Text(
                         "$activeUsers staff",
                         style: TextStyle(
                           fontSize: 10,
                           fontWeight: FontWeight.w600,
                           color: isSelected && !isMobile
                               ? Colors.indigo
                               : (isDark ? Colors.white70 : Colors.black54),
                         ),
                       ),
                     ),
                   ],
                 ),
               ],
             ),
           ),
         );
       },
     );
  }

  Widget _buildStaffList({WorkLocation? location}) {
    final targetLocation = location ?? _selectedLocation;

    if (targetLocation == null) {
      return const Center(child: Text("Select a location", style: TextStyle(color: Colors.grey)));
    }
    if (_isLoadingUsers) return const SizedBox.shrink();

    // Filter to only assigned users
    final assignedUsers = _users.where((user) {
      final List<dynamic>? userLocs = user['work_locations'];
      if (userLocs == null) return false;
      return userLocs.any((l) => l is Map && (l['location_id'] == targetLocation.id || l['loc_id'] == targetLocation.id));
    }).toList();

    if (assignedUsers.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.people_outline, size: 40, color: Colors.grey.withValues(alpha: 0.5)),
            const SizedBox(height: 8),
            const Text(
              "No staff assigned",
              style: TextStyle(color: Colors.grey, fontSize: 13),
            ),
          ],
        ),
      );
    }
    
    return ListView.builder(
      padding: const EdgeInsets.all(12),
      itemCount: assignedUsers.length,
      itemBuilder: (context, index) {
        final user = assignedUsers[index];
        final name = user['user_name'] ?? 'Unknown'; 
        final role = user['desg_name'] ?? 'Staff';
        final int userId = user['user_id'] ?? 0;
        final profileImage = _resolveAvatarUrl(user['profile_image'] ?? user['profile_image_url'] ?? user['avatar_url']);

        return Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: Row(
            children: [
              CircleAvatar(
                radius: 16,
                backgroundColor: Colors.indigo[100],
                backgroundImage: (profileImage != null && profileImage.isNotEmpty)
                    ? NetworkImage(profileImage)
                    : null,
                child: (profileImage == null || profileImage.isEmpty)
                    ? Text(name.isNotEmpty ? name[0].toUpperCase() : '?', style: const TextStyle(color: Colors.indigo, fontWeight: FontWeight.bold, fontSize: 12))
                    : null,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(name, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                    Text(role, style: const TextStyle(fontSize: 11, color: Colors.grey)),
                  ],
                ),
              ),
              IconButton(
                icon: const Icon(Icons.remove_circle_outline),
                color: Colors.red[300],
                tooltip: "Remove Staff",
                onPressed: () => _toggleUserAssignment(userId, name, true), // Passing isAssigned = true will remove them
              )
            ],
          ),
        );
      },
    );
  }
  
  void _showMobileDetailSheet(WorkLocation loc) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (ctx) => _MobileStaffManagementSheet(
        location: loc,
        locationService: widget.locationService,
        initialUsers: _users,
        onAssignmentChanged: () {
          _fetchUsers();
          _fetchLocations();
        },
      ),
    );
  }

  void _showAssignStaffDialog(BuildContext context, WorkLocation loc) {
    showDialog(
      context: context,
      barrierDismissible: true,
      builder: (ctx) => Dialog(
        backgroundColor: Colors.transparent,
        surfaceTintColor: Colors.transparent,
        insetPadding: const EdgeInsets.all(16),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 500, maxHeight: 650),
          child: GlassContainer(
            color: Theme.of(context).brightness == Brightness.dark
                ? const Color(0xFF161B22)
                : Colors.white,
            borderRadius: 24,
            padding: EdgeInsets.zero,
            child: AssignStaffPopupContent(
              location: loc,
              locationService: widget.locationService,
              initialUsers: _users,
              onAssignmentChanged: () {
                _fetchUsers();
                _fetchLocations();
              },
            ),
          ),
        ),
      ),
    );
  }

}

class _LocationFormDialog extends StatefulWidget {
  final Function(Map<String, dynamic>) onSubmit;
  const _LocationFormDialog({required this.onSubmit});

  @override
  __LocationFormDialogState createState() => __LocationFormDialogState();
}

class __LocationFormDialogState extends State<_LocationFormDialog> {
  final _nameCtrl = TextEditingController();
  final _addressCtrl = TextEditingController();
  final _latCtrl = TextEditingController();
  final _lngCtrl = TextEditingController();
  double _radius = 100;

  @override
  Widget build(BuildContext context) {
      final isDark = Theme.of(context).brightness == Brightness.dark;
      
      // Theme Colors
      final glassColor = isDark ? const Color(0xFF161B22) : Colors.white;
      final textColor = isDark ? Colors.white : Colors.black87;
      final hintColor = isDark ? Colors.white54 : Colors.grey;

      return Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: const EdgeInsets.all(16),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 500),
          child: GlassContainer(
              color: glassColor,
              borderRadius: 24,
              padding: const EdgeInsets.all(28),
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Header
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text("New Geofence", style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: textColor)),
                        IconButton(icon: Icon(Icons.close, color: hintColor), onPressed: () => Navigator.pop(context)),
                      ],
                    ),
                    const SizedBox(height: 24),
                    
                    // Form Fields
                    _GlassTextField(controller: _nameCtrl, label: "Location Name", icon: Icons.business, isDark: isDark),
                    const SizedBox(height: 16),
                    _GlassTextField(controller: _addressCtrl, label: "Address", icon: Icons.map, isDark: isDark),
                    const SizedBox(height: 16),
                    
                    LayoutBuilder(
                      builder: (context, constraints) {
                         if (constraints.maxWidth > 400) {
                           // Side by Side
                           return Row(
                             children: [
                               Expanded(child: _GlassTextField(controller: _latCtrl, label: "Latitude", icon: Icons.gps_fixed, isNumeric: true, isDark: isDark)),
                               const SizedBox(width: 16),
                               Expanded(child: _GlassTextField(controller: _lngCtrl, label: "Longitude", icon: Icons.gps_fixed, isNumeric: true, isDark: isDark)),
                             ],
                           );
                         }
                         return Column(
                           children: [
                              _GlassTextField(controller: _latCtrl, label: "Latitude", icon: Icons.gps_fixed, isNumeric: true, isDark: isDark),
                              const SizedBox(height: 16),
                              _GlassTextField(controller: _lngCtrl, label: "Longitude", icon: Icons.gps_fixed, isNumeric: true, isDark: isDark),
                           ],
                         );
                      },
                    ),
                    
                    const SizedBox(height: 24),
                    
                    // Radius Slider
                    Text("Radius: ${_radius.toInt()} meters", style: TextStyle(color: textColor, fontWeight: FontWeight.w600)),
                    const SizedBox(height: 8),
                    SliderTheme(
                      data: SliderTheme.of(context).copyWith(
                        trackHeight: 6,
                        activeTrackColor: Colors.indigo,
                        inactiveTrackColor: isDark ? Colors.white24 : Colors.grey[300],
                        thumbColor: Colors.white,
                        overlayColor: Colors.indigo.withValues(alpha: 0.2),
                      ),
                      child: Slider(
                        value: _radius, 
                        min: 0, 
                        max: 2000, 
                        onChanged: (v) => setState(() => _radius = v)
                      ),
                    ),

                    const SizedBox(height: 32),
                    
                    // Action Button
                    SizedBox(
                      width: double.infinity,
                      height: 50,
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.indigo,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          elevation: 0,
                        ),
                        onPressed: () {
                           if (_nameCtrl.text.isEmpty || _latCtrl.text.isEmpty) return;
                           widget.onSubmit({
                              "location_name": _nameCtrl.text,
                              "address": _addressCtrl.text,
                              "latitude": double.tryParse(_latCtrl.text) ?? 0.0,
                              "longitude": double.tryParse(_lngCtrl.text) ?? 0.0,
                              "radius": _radius.toInt()
                           });
                        },
                        child: const Text("Create Location", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                      ),
                    )
                  ],
                ),
              ),
          ),
        ),
      );
  }
}

class _GlassTextField extends StatelessWidget {
  final TextEditingController controller;
  final String label;
  final IconData icon;
  final bool isNumeric;
  final bool isDark;

  const _GlassTextField({
    required this.controller,
    required this.label,
    required this.icon,
    this.isNumeric = false,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF0D1117) : Colors.grey[100],
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: isDark ? Colors.white10 : Colors.grey[300]!),
      ),
      child: TextField(
        controller: controller,
        keyboardType: isNumeric ? TextInputType.number : TextInputType.text,
        style: TextStyle(color: isDark ? Colors.white : Colors.black87),
        decoration: InputDecoration(
          prefixIcon: Icon(icon, color: isDark ? Colors.white54 : Colors.grey),
          labelText: label,
          labelStyle: TextStyle(color: isDark ? Colors.white54 : Colors.grey),
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        ),
      ),
    );
  }
}

class _MobileStaffManagementSheet extends StatefulWidget {
  final WorkLocation location;
  final LocationService locationService;
  final List<Map<String, dynamic>> initialUsers;
  final VoidCallback onAssignmentChanged;

  const _MobileStaffManagementSheet({
    required this.location,
    required this.locationService,
    required this.initialUsers,
    required this.onAssignmentChanged,
  });

  @override
  __MobileStaffManagementSheetState createState() => __MobileStaffManagementSheetState();
}

class __MobileStaffManagementSheetState extends State<_MobileStaffManagementSheet> {
  bool _isAssignMode = false;
  late List<Map<String, dynamic>> _users;

  @override
  void initState() {
    super.initState();
    _users = widget.initialUsers;
  }

  void _refreshUsers() async {
    try {
      final updatedUsers = await widget.locationService.getUsersWithLocations();
      if (mounted) {
        setState(() {
          _users = updatedUsers;
        });
      }
    } catch (e) {
      debugPrint("Error reloading users: $e");
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    final assignedUsers = _users.where((user) {
      final List<dynamic>? userLocs = user['work_locations'];
      if (userLocs == null) return false;
      return userLocs.any((l) => l is Map && (l['location_id'] == widget.location.id || l['loc_id'] == widget.location.id));
    }).toList();

    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).scaffoldBackgroundColor,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      height: MediaQuery.of(context).size.height * 0.85,
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: _isAssignMode
          ? AssignStaffPopupContent(
              location: widget.location,
              locationService: widget.locationService,
              initialUsers: _users,
              onAssignmentChanged: () {
                widget.onAssignmentChanged();
                _refreshUsers();
              },
              onBack: () {
                setState(() {
                  _isAssignMode = false;
                });
              },
            )
          : ListView.builder(
              padding: const EdgeInsets.only(bottom: 24),
              itemCount: assignedUsers.isEmpty ? 3 : assignedUsers.length + 2,
              itemBuilder: (ctx, index) {
                if (index == 0) {
                  return Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                widget.location.name,
                                style: GoogleFonts.poppins(
                                  fontSize: 20,
                                  fontWeight: FontWeight.bold,
                                  color: isDark ? Colors.white : Colors.black87,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                              Text(
                                "Assigned Staff (${assignedUsers.length})",
                                style: GoogleFonts.poppins(
                                  fontSize: 13,
                                  color: Colors.indigo.withValues(alpha: 0.8),
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                        ),
                        Row(
                          children: [
                            IconButton(
                              icon: const Icon(Icons.person_add_alt_1_outlined, color: Colors.indigo),
                              tooltip: "Assign Staff",
                              onPressed: () {
                                setState(() {
                                  _isAssignMode = true;
                                });
                              },
                            ),
                            IconButton(
                              icon: const Icon(Icons.close),
                              onPressed: () => Navigator.pop(context),
                            ),
                          ],
                        ),
                      ],
                    ),
                  );
                }
                if (index == 1) {
                  return const Divider(height: 1);
                }
                
                if (index == 2 && assignedUsers.isEmpty) {
                  return Padding(
                    padding: const EdgeInsets.only(top: 80),
                    child: Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.people_outline, size: 48, color: Colors.grey.withValues(alpha: 0.5)),
                          const SizedBox(height: 12),
                          Text(
                            "No staff assigned to this location",
                            style: GoogleFonts.poppins(color: Colors.grey, fontSize: 14),
                          ),
                          const SizedBox(height: 16),
                          ElevatedButton.icon(
                            onPressed: () {
                              setState(() {
                                _isAssignMode = true;
                              });
                            },
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.indigo,
                              foregroundColor: Colors.white,
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                              elevation: 0,
                            ),
                            icon: const Icon(Icons.person_add_alt_1_outlined, size: 18),
                            label: const Text("Assign Staff"),
                          )
                        ],
                      ),
                    ),
                  );
                }

                final userIndex = index - 2;
                final user = assignedUsers[userIndex];
                final name = user['user_name'] ?? 'Unknown';
                final role = user['desg_name'] ?? 'Staff';
                final int userId = user['user_id'] ?? 0;
                final profileImage = _resolveAvatarUrl(user['profile_image'] ?? user['profile_image_url'] ?? user['avatar_url']);

                return Container(
                  margin: const EdgeInsets.symmetric(horizontal: 24, vertical: 4),
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  decoration: BoxDecoration(
                    color: isDark ? const Color(0xFF161B22) : Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: isDark ? const Color(0xFF30363D) : Colors.grey[200]!,
                    ),
                  ),
                  child: Row(
                    children: [
                      CircleAvatar(
                        radius: 18,
                        backgroundColor: Colors.indigo[100],
                        backgroundImage: (profileImage != null && profileImage.isNotEmpty)
                            ? NetworkImage(profileImage)
                            : null,
                        child: (profileImage == null || profileImage.isEmpty)
                            ? Text(
                                name.isNotEmpty ? name[0].toUpperCase() : '?',
                                style: const TextStyle(
                                  color: Colors.indigo,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 14,
                                ),
                              )
                            : null,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              name,
                              style: GoogleFonts.poppins(
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                                color: isDark ? Colors.white : Colors.black87,
                              ),
                            ),
                            Text(
                              role,
                              style: GoogleFonts.poppins(
                                fontSize: 12,
                                color: Colors.grey,
                              ),
                            ),
                          ],
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.remove_circle_outline, color: Colors.red),
                        onPressed: () async {
                          setState(() {
                            final idx = _users.indexWhere((u) => u['user_id'] == userId);
                            if (idx != -1) {
                              final userCopy = Map<String, dynamic>.from(_users[idx]);
                              final List<dynamic> currentLocs = List<dynamic>.from(userCopy['work_locations'] ?? []);
                              currentLocs.removeWhere((l) =>
                                  l is Map && (l['location_id'] == widget.location.id || l['loc_id'] == widget.location.id));
                              userCopy['work_locations'] = currentLocs;
                              _users[idx] = userCopy;
                            }
                          });
                          
                          try {
                            await widget.locationService.assignUser(widget.location.id, userId, false);
                            widget.onAssignmentChanged();
                            _refreshUsers();
                          } catch (e) {
                            _refreshUsers();
                            if (context.mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(content: Text("Failed to remove staff: $e")),
                              );
                            }
                          }
                        },
                      ),
                    ],
                  ),
                );
              },
            ),
    );
  }
}

class AssignStaffPopupContent extends StatefulWidget {
  final WorkLocation location;
  final LocationService locationService;
  final List<Map<String, dynamic>> initialUsers;
  final VoidCallback onAssignmentChanged;
  final VoidCallback? onBack;

  const AssignStaffPopupContent({
    super.key,
    required this.location,
    required this.locationService,
    required this.initialUsers,
    required this.onAssignmentChanged,
    this.onBack,
  });

  @override
  State<AssignStaffPopupContent> createState() => _AssignStaffPopupContentState();
}

class _AssignStaffPopupContentState extends State<AssignStaffPopupContent> {
  late List<Map<String, dynamic>> _localUsers;
  String _searchQuery = "";
  final TextEditingController _searchCtrl = TextEditingController();

  // Toast state
  bool _isToastVisible = false;
  String? _toastMessage;
  bool _isToastSuccess = false;
  bool _isToastError = false;

  @override
  void initState() {
    super.initState();
    _localUsers = List<Map<String, dynamic>>.from(widget.initialUsers);
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  void _showLocalToast(String message, {bool isSuccess = false, bool isError = false}) {
    if (!mounted) return;
    setState(() {
      _toastMessage = message;
      _isToastSuccess = isSuccess;
      _isToastError = isError;
      _isToastVisible = true;
    });

    // Auto dismiss after 2.5 seconds
    Future.delayed(const Duration(milliseconds: 2500), () {
      if (mounted) {
        setState(() {
          _isToastVisible = false;
        });
        Future.delayed(const Duration(milliseconds: 300), () {
          if (mounted && !_isToastVisible) {
            setState(() {
              _toastMessage = null;
            });
          }
        });
      }
    });
  }

  Future<void> _toggleAssignment(int userId, String userName, bool isCurrentlyAssigned) async {
    final isAdding = !isCurrentlyAssigned;
    final targetLocId = widget.location.id;

    setState(() {
      final idx = _localUsers.indexWhere((u) => u['user_id'] == userId);
      if (idx != -1) {
        final userCopy = Map<String, dynamic>.from(_localUsers[idx]);
        final List<dynamic> currentLocs = List<dynamic>.from(userCopy['work_locations'] ?? []);
        
        if (isAdding) {
          currentLocs.add({
            'location_id': targetLocId,
            'loc_id': targetLocId,
          });
        } else {
          currentLocs.removeWhere((l) =>
              l is Map && (l['location_id'] == targetLocId || l['loc_id'] == targetLocId));
        }
        userCopy['work_locations'] = currentLocs;
        _localUsers[idx] = userCopy;
      }
    });

    _showLocalToast(
      isAdding ? "Assigning $userName..." : "Removing $userName...",
      isSuccess: false,
    );

    try {
      await widget.locationService.assignUser(targetLocId, userId, isAdding);
      widget.onAssignmentChanged();
      
      _showLocalToast(
        isAdding ? "$userName assigned successfully" : "$userName removed successfully",
        isSuccess: true,
      );
    } catch (e) {
      setState(() {
        final idx = _localUsers.indexWhere((u) => u['user_id'] == userId);
        if (idx != -1) {
          final userCopy = Map<String, dynamic>.from(_localUsers[idx]);
          final List<dynamic> currentLocs = List<dynamic>.from(userCopy['work_locations'] ?? []);
          
          if (isAdding) {
            currentLocs.removeWhere((l) =>
                l is Map && (l['location_id'] == targetLocId || l['loc_id'] == targetLocId));
          } else {
            currentLocs.add({
              'location_id': targetLocId,
              'loc_id': targetLocId,
            });
          }
          userCopy['work_locations'] = currentLocs;
          _localUsers[idx] = userCopy;
        }
      });
      _showLocalToast("Failed: $e", isError: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    final filteredUsers = _localUsers.where((user) {
      final name = (user['user_name'] ?? '').toString().toLowerCase();
      final role = (user['desg_name'] ?? '').toString().toLowerCase();
      final query = _searchQuery.toLowerCase();
      return name.contains(query) || role.contains(query);
    }).toList();

    final textColor = isDark ? Colors.white : Colors.black87;
    final subtitleColor = isDark ? Colors.white70 : Colors.black54;

    final isMobile = MediaQuery.of(context).size.width < 600;
    final contentHeight = isMobile 
        ? MediaQuery.of(context).size.height * 0.78 
        : 600.0;

    return SizedBox(
      height: contentHeight,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Positioned.fill(
            child: ListView.builder(
              padding: const EdgeInsets.only(bottom: 24),
              itemCount: filteredUsers.isEmpty ? 3 : filteredUsers.length + 2,
              itemBuilder: (context, index) {
                if (index == 0) {
                  return Padding(
                    padding: const EdgeInsets.fromLTRB(24, 24, 24, 0),
                    child: Row(
                      children: [
                        if (widget.onBack != null)
                          IconButton(
                            icon: const Icon(Icons.arrow_back),
                            onPressed: widget.onBack,
                          ),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                "Assign Staff",
                                style: GoogleFonts.poppins(
                                  fontSize: 20,
                                  fontWeight: FontWeight.bold,
                                  color: textColor,
                                ),
                              ),
                              Text(
                                "Location: ${widget.location.name}",
                                style: GoogleFonts.poppins(
                                  fontSize: 12,
                                  color: subtitleColor,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ],
                          ),
                        ),
                        if (widget.onBack == null)
                          IconButton(
                            icon: const Icon(Icons.close),
                            onPressed: () => Navigator.pop(context),
                          ),
                      ],
                    ),
                  );
                }
                if (index == 1) {
                  return Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                    child: Container(
                      decoration: BoxDecoration(
                        color: isDark ? const Color(0xFF0D1117) : Colors.grey[100],
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: isDark ? Colors.white10 : Colors.grey[300]!),
                      ),
                      child: TextField(
                        controller: _searchCtrl,
                        style: TextStyle(color: textColor),
                        onChanged: (val) {
                          setState(() {
                            _searchQuery = val;
                          });
                        },
                        decoration: InputDecoration(
                          prefixIcon: const Icon(Icons.search, size: 20),
                          suffixIcon: _searchQuery.isNotEmpty
                              ? IconButton(
                                  icon: const Icon(Icons.clear, size: 18),
                                  onPressed: () {
                                    _searchCtrl.clear();
                                    setState(() {
                                      _searchQuery = "";
                                    });
                                  },
                                )
                              : null,
                          hintText: "Search employees...",
                          hintStyle: TextStyle(color: isDark ? Colors.white30 : Colors.grey),
                          border: InputBorder.none,
                          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                        ),
                      ),
                    ),
                  );
                }
                if (index == 2 && filteredUsers.isEmpty) {
                  return const Padding(
                    padding: EdgeInsets.symmetric(vertical: 40),
                    child: Center(
                      child: Text(
                        "No employees found",
                        style: TextStyle(color: Colors.grey, fontSize: 14),
                      ),
                    ),
                  );
                }

                final userIndex = index - 2;
                final user = filteredUsers[userIndex];
                final name = user['user_name'] ?? 'Unknown';
                final role = user['desg_name'] ?? 'Staff';
                final int userId = user['user_id'] ?? 0;
                final profileImage = _resolveAvatarUrl(user['profile_image'] ?? user['profile_image_url'] ?? user['avatar_url']);
                
                final List<dynamic>? userLocs = user['work_locations'];
                bool isAssigned = false;
                if (userLocs != null) {
                  isAssigned = userLocs.any((l) =>
                      l is Map && (l['location_id'] == widget.location.id || l['loc_id'] == widget.location.id));
                }

                return Container(
                  margin: const EdgeInsets.symmetric(horizontal: 24, vertical: 4),
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: isDark
                        ? (isAssigned ? Colors.indigo.withValues(alpha: 0.1) : Colors.transparent)
                        : (isAssigned ? Colors.indigo[50]!.withValues(alpha: 0.5) : Colors.transparent),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: isAssigned
                          ? Colors.indigo.withValues(alpha: 0.2)
                          : Colors.transparent,
                    ),
                  ),
                  child: Row(
                    children: [
                      CircleAvatar(
                        radius: 18,
                        backgroundColor: isDark
                            ? Colors.indigo.withValues(alpha: 0.2)
                            : Colors.indigo[100],
                        backgroundImage: (profileImage != null && profileImage.isNotEmpty)
                            ? NetworkImage(profileImage)
                            : null,
                        child: (profileImage == null || profileImage.isEmpty)
                            ? Text(
                                name.isNotEmpty ? name[0].toUpperCase() : '?',
                                style: const TextStyle(
                                  color: Colors.indigo,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 14,
                                ),
                              )
                            : null,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              name,
                              style: GoogleFonts.poppins(
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                                color: textColor,
                              ),
                            ),
                            Text(
                              role,
                              style: GoogleFonts.poppins(
                                fontSize: 12,
                                color: Colors.grey,
                              ),
                            ),
                          ],
                        ),
                      ),
                      _buildToggleButton(userId, name, isAssigned),
                    ],
                  ),
                );
              },
            ),
          ),
          AnimatedPositioned(
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeOutBack,
            bottom: _isToastVisible ? 16.0 : -80.0,
            left: 0,
            right: 0,
            child: AnimatedOpacity(
              duration: const Duration(milliseconds: 200),
              opacity: _isToastVisible ? 1.0 : 0.0,
              child: _toastMessage == null 
                  ? const SizedBox.shrink() 
                  : Center(
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                        decoration: BoxDecoration(
                          color: _isToastError
                              ? const Color(0xFFDA3637)
                              : (_isToastSuccess ? const Color(0xFF2EA043) : Colors.indigo),
                          borderRadius: BorderRadius.circular(12),
                          boxShadow: const [
                            BoxShadow(
                              color: Colors.black26,
                              blurRadius: 10,
                              offset: Offset(0, 4),
                            )
                          ],
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            if (!_isToastSuccess && !_isToastError)
                              const SizedBox(
                                width: 14,
                                height: 14,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                                ),
                              )
                            else
                              Icon(
                                _isToastError
                                    ? Icons.error_outline
                                    : Icons.check_circle_outline,
                                color: Colors.white,
                                size: 18,
                              ),
                            const SizedBox(width: 8),
                            Text(
                              _toastMessage!,
                              style: GoogleFonts.poppins(
                                color: Colors.white,
                                fontSize: 13,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildToggleButton(int userId, String name, bool isAssigned) {
    return InkWell(
      onTap: () => _toggleAssignment(userId, name, isAssigned),
      borderRadius: BorderRadius.circular(20),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: isAssigned ? Colors.green : Colors.indigo,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              isAssigned ? Icons.check : Icons.add,
              color: Colors.white,
              size: 14,
            ),
            const SizedBox(width: 4),
            Text(
              isAssigned ? "Assigned" : "Assign",
              style: GoogleFonts.poppins(
                color: Colors.white,
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
