import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/firebase_constants.dart';
import '../../domain/entities/user_entity.dart';

class PerfilUsuarioScreen extends StatefulWidget {
  final UserEntity currentUser;

  const PerfilUsuarioScreen({
    super.key,
    required this.currentUser,
  });

  @override
  State<PerfilUsuarioScreen> createState() => _PerfilUsuarioScreenState();
}

class _PerfilUsuarioScreenState extends State<PerfilUsuarioScreen> {
  final _formKey = GlobalKey<FormState>();

  late final TextEditingController _nombreController;
  late final TextEditingController _rutController;
  late final TextEditingController _telefonoController;
  late final TextEditingController _direccionController;
  late final TextEditingController _juntaController;

  String? _selectedCiudad;
  bool _isSaving = false;

  final List<String> _ciudadesChile = [
    'Alto Hospicio',
    'Iquique',
    'Antofagasta',
    'Calama',
    'Arica',
    'Tocopilla',
    'Copiapó',
    'La Serena',
    'Coquimbo',
    'Valparaíso',
    'Viña del Mar',
    'Santiago',
    'Concepción',
    'Temuco',
    'Puerto Montt',
    'Otra ciudad',
  ];

  @override
  void initState() {
    super.initState();
    _nombreController = TextEditingController(text: widget.currentUser.nombre ?? '');
    _rutController = TextEditingController(text: widget.currentUser.rut ?? '');
    _telefonoController = TextEditingController(text: widget.currentUser.telefono ?? '');
    _direccionController = TextEditingController(text: widget.currentUser.direccion ?? '');
    _juntaController = TextEditingController(text: widget.currentUser.juntaVecinal ?? '');

    if (widget.currentUser.ciudad != null &&
        _ciudadesChile.contains(widget.currentUser.ciudad)) {
      _selectedCiudad = widget.currentUser.ciudad;
    } else if (widget.currentUser.ciudad != null && widget.currentUser.ciudad!.isNotEmpty) {
      _selectedCiudad = 'Otra ciudad';
    } else {
      _selectedCiudad = 'Alto Hospicio'; // Predeterminado según caso de estudio
    }
  }

  @override
  void dispose() {
    _nombreController.dispose();
    _rutController.dispose();
    _telefonoController.dispose();
    _direccionController.dispose();
    _juntaController.dispose();
    super.dispose();
  }

  Future<void> _guardarPerfil() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isSaving = true);

    final updatedUser = widget.currentUser.copyWith(
      nombre: _nombreController.text.trim(),
      rut: _rutController.text.trim(),
      ciudad: _selectedCiudad,
      telefono: _telefonoController.text.trim(),
      direccion: _direccionController.text.trim(),
      juntaVecinal: _juntaController.text.trim(),
    );

    try {
      final docData = <String, dynamic>{
        'uid': updatedUser.uid,
        'email': updatedUser.email,
        'rol': updatedUser.rol,
        'nombre': updatedUser.nombre,
        'rut': updatedUser.rut,
        'ciudad': updatedUser.ciudad,
        'telefono': updatedUser.telefono,
        'direccion': updatedUser.direccion,
        'junta_vecinal': updatedUser.juntaVecinal,
        'actualizado_en': FieldValue.serverTimestamp(),
      };

      await FirebaseFirestore.instance
          .collection(FirebaseConstants.colUsuarios)
          .doc(updatedUser.uid)
          .set(docData, SetOptions(merge: true))
          .timeout(
            const Duration(seconds: 4),
            onTimeout: () {
              debugPrint('[Perfil] Perfil guardado con persistencia offline.');
            },
          );

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          backgroundColor: AppColors.successGreen,
          content: Row(
            children: [
              Icon(Icons.check_circle_outline, color: Colors.white),
              SizedBox(width: 8),
              Expanded(child: Text('Perfil ciudadano actualizado correctamente.')),
            ],
          ),
          duration: Duration(seconds: 3),
        ),
      );

      Navigator.pop(context, updatedUser);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: AppColors.panicRed,
          content: Text('Error al actualizar perfil: $e'),
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _isSaving = false);
      }
    }
  }

  String _getRolLabel(String rol) {
    switch (rol.toLowerCase()) {
      case 'dirigente':
        return '🏛️ Presidente / Dirigente Junta Vecinal';
      case 'institucional':
      case 'carabineros':
      case 'pdi':
        return '🚓 Carabineros / PDI (Seguridad)';
      default:
        return '👤 Ciudadano Vecino';
    }
  }

  Color _getRolColor(String rol) {
    switch (rol.toLowerCase()) {
      case 'dirigente':
        return const Color(0xFFD97706); // Amber
      case 'institucional':
      case 'carabineros':
      case 'pdi':
        return const Color(0xFF1E3A8A); // Deep Navy
      default:
        return AppColors.primary;
    }
  }

  @override
  Widget build(BuildContext context) {
    final rolColor = _getRolColor(widget.currentUser.rol);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Mi Perfil Ciudadano'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20.0),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Cabecera con avatar y rol
              Center(
                child: Column(
                  children: [
                    CircleAvatar(
                      radius: 42,
                      backgroundColor: rolColor.withOpacity(0.15),
                      child: Icon(Icons.person_rounded, size: 52, color: rolColor),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      widget.currentUser.email,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: AppColors.primaryDark,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
                      decoration: BoxDecoration(
                        color: rolColor.withOpacity(0.12),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: rolColor.withOpacity(0.4)),
                      ),
                      child: Text(
                        _getRolLabel(widget.currentUser.rol),
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: rolColor,
                        ),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Reputación Comunitaria: ${widget.currentUser.reputacion} pts',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: widget.currentUser.reputacion >= 70
                            ? AppColors.successGreen
                            : AppColors.warningOrange,
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 24),
              const Divider(),
              const SizedBox(height: 16),

              const Text(
                'Datos de Identificación y Contacto',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.bold,
                  color: AppColors.primaryDark,
                ),
              ),
              const SizedBox(height: 16),

              // Nombre Completo
              TextFormField(
                controller: _nombreController,
                decoration: const InputDecoration(
                  labelText: 'Nombre Completo',
                  hintText: 'Ej: Juan Pérez Morales',
                  prefixIcon: Icon(Icons.badge_outlined),
                ),
                validator: (val) {
                  if (val == null || val.trim().isEmpty) {
                    return 'Ingrese su nombre completo';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),

              // RUT
              TextFormField(
                controller: _rutController,
                decoration: const InputDecoration(
                  labelText: 'RUT Chileno',
                  hintText: 'Ej: 12.345.678-9',
                  prefixIcon: Icon(Icons.fingerprint_rounded),
                ),
                validator: (val) {
                  if (val == null || val.trim().isEmpty) {
                    return 'Ingrese su RUT para validación comunitaria';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),

              // Ciudad de residencia (ej: Alto Hospicio / Iquique)
              DropdownButtonFormField<String>(
                value: _selectedCiudad,
                decoration: const InputDecoration(
                  labelText: 'Ciudad de Residencia',
                  prefixIcon: Icon(Icons.location_city_rounded),
                ),
                items: _ciudadesChile.map((ciudad) {
                  return DropdownMenuItem(
                    value: ciudad,
                    child: Text(ciudad),
                  );
                }).toList(),
                onChanged: (val) {
                  setState(() => _selectedCiudad = val);
                },
              ),
              const SizedBox(height: 16),

              // Teléfono de contacto
              TextFormField(
                controller: _telefonoController,
                keyboardType: TextInputType.phone,
                decoration: const InputDecoration(
                  labelText: 'Teléfono Móvil de Contacto',
                  hintText: 'Ej: +56 9 8765 4321',
                  prefixIcon: Icon(Icons.phone_outlined),
                ),
              ),
              const SizedBox(height: 16),

              // Dirección / Sector
              TextFormField(
                controller: _direccionController,
                decoration: const InputDecoration(
                  labelText: 'Dirección / Calle / Población',
                  hintText: 'Ej: Av. Las Parcelas #1234',
                  prefixIcon: Icon(Icons.home_outlined),
                ),
              ),
              const SizedBox(height: 16),

              // Junta de Vecinos
              TextFormField(
                controller: _juntaController,
                decoration: const InputDecoration(
                  labelText: 'Junta de Vecinos / Cuadrante',
                  hintText: 'Ej: Junta de Vecinos N° 12 Santa Rosa',
                  prefixIcon: Icon(Icons.groups_outlined),
                ),
              ),

              const SizedBox(height: 28),

              // Botón Guardar
              ElevatedButton.icon(
                onPressed: _isSaving ? null : _guardarPerfil,
                icon: _isSaving
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                        ),
                      )
                    : const Icon(Icons.save_outlined),
                label: const Text('Guardar Información de Perfil'),
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
