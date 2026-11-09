import 'dart:async';
import 'package:flutter/material.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_constants.dart';
import '../../../home/presentation/screens/home_view.dart';
import '../../../network/data/datasources/contacts_device_datasource.dart';
import '../../../network/data/datasources/network_remote_datasource.dart';
import '../../../network/data/repositories/network_repository_impl.dart';
import '../../../network/domain/entities/trusted_contact_entity.dart';
import '../../../network/domain/repositories/network_repository.dart';
import '../../../network/presentation/widgets/credencial_civitas_badge.dart';
import '../../data/datasources/auth_remote_datasource.dart';
import '../../data/repositories/auth_repository_impl.dart';
import '../../domain/entities/user_entity.dart';
import '../../domain/repositories/auth_repository.dart';
import '../../domain/usecases/complete_profile_usecase.dart';

/// Flujo de configuración inicial (Onboarding) obligatorio para usuarios nuevos.
/// Cumple con las directrices de la Tesis CIVITAS para asegurar perfiles verificados
/// y una red de confianza vecinal inicial antes de acceder a la plataforma.
class OnboardingWizardScreen extends StatefulWidget {
  final UserEntity currentUser;
  final AuthRepository? authRepository;
  final NetworkRepository? networkRepository;
  final void Function(UserEntity user)? onCompleted;

  const OnboardingWizardScreen({
    super.key,
    required this.currentUser,
    this.authRepository,
    this.networkRepository,
    this.onCompleted,
  });

  @override
  State<OnboardingWizardScreen> createState() => _OnboardingWizardScreenState();
}

class _OnboardingWizardScreenState extends State<OnboardingWizardScreen> {
  late final AuthRepository _authRepository;
  late final NetworkRepository _networkRepository;
  late final CompleteProfileUseCase _completeProfileUseCase;

  int _currentStep = 0;
  bool _isLoading = false;
  String? _errorMessage;

  // Formulario Paso 1: Perfil Cívico
  final _formKeyStep1 = GlobalKey<FormState>();
  late final TextEditingController _nameController;
  late final TextEditingController _rutController;
  late final TextEditingController _phoneController;
  late final TextEditingController _cityController;
  late final TextEditingController _addressController;
  late final TextEditingController _juntaVecinalController;

  // Paso 2: Red de Confianza
  List<TrustedContactEntity> _deviceContacts = [];
  final Set<String> _selectedContactIds = {};
  bool _loadingContacts = false;
  final List<TrustedContactEntity> _customAddedContacts = [];

  // Paso 3: Compromiso Cívico
  bool _acceptedCommitment = true;

  @override
  void initState() {
    super.initState();
    _authRepository = widget.authRepository ??
        AuthRepositoryImpl(remoteDataSource: AuthRemoteDataSourceImpl());
    _networkRepository = widget.networkRepository ??
        NetworkRepositoryImpl(
          remoteDataSource: NetworkRemoteDataSourceImpl(),
          deviceDataSource: ContactsDeviceDataSourceImpl(),
        );
    _completeProfileUseCase = CompleteProfileUseCase(_authRepository);

    _nameController = TextEditingController(text: widget.currentUser.nombre ?? '');
    _rutController = TextEditingController(text: widget.currentUser.rut ?? '');
    _phoneController = TextEditingController(text: widget.currentUser.telefono ?? '');
    _cityController = TextEditingController(text: widget.currentUser.ciudad?.isNotEmpty == true ? widget.currentUser.ciudad! : 'Iquique');
    _addressController = TextEditingController(text: widget.currentUser.direccion ?? '');
    _juntaVecinalController = TextEditingController(text: widget.currentUser.juntaVecinal ?? '');

    _loadDeviceContacts();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _rutController.dispose();
    _phoneController.dispose();
    _cityController.dispose();
    _addressController.dispose();
    _juntaVecinalController.dispose();
    super.dispose();
  }

  Future<void> _loadDeviceContacts() async {
    setState(() => _loadingContacts = true);
    try {
      final contacts = await _networkRepository.getDevicePhoneContacts();
      if (mounted) {
        setState(() {
          _deviceContacts = contacts;
          // Seleccionar por defecto el primer contacto como sugerencia
          if (_deviceContacts.isNotEmpty) {
            _selectedContactIds.add(_deviceContacts.first.id);
          }
          _loadingContacts = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _loadingContacts = false);
    }
  }

  Future<void> _finishOnboarding() async {
    if (!_acceptedCommitment) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Debes aceptar el compromiso cívico de seguridad para activar tu credencial.'),
          backgroundColor: AppColors.panicRed,
        ),
      );
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      // 1. Guardar y completar perfil en Firestore
      final updatedUser = await _completeProfileUseCase.call(
        uid: widget.currentUser.uid,
        nombre: _nameController.text.trim(),
        rut: _rutController.text.trim(),
        telefono: _phoneController.text.trim(),
        ciudad: _cityController.text.trim(),
        direccion: _addressController.text.trim(),
        juntaVecinal: _juntaVecinalController.text.trim().isNotEmpty
            ? _juntaVecinalController.text.trim()
            : null,
      ).timeout(
        const Duration(seconds: 10),
        onTimeout: () => throw TimeoutException('Tiempo de espera agotado al guardar perfil y credencial.'),
      );

      // 2. Guardar contactos de confianza seleccionados
      final contactsToSave = <TrustedContactEntity>[
        ..._deviceContacts.where((c) => _selectedContactIds.contains(c.id)),
        ..._customAddedContacts,
      ];

      for (final contact in contactsToSave) {
        await _networkRepository.addTrustedContact(
          userUid: updatedUser.uid,
          contact: contact,
        );
        // Enviar solicitud de confianza formal con la credencial del nuevo usuario
        await _networkRepository.sendTrustRequest(
          fromUser: updatedUser,
          toPhone: contact.phone,
        );
      }

      if (!mounted) return;

      setState(() => _isLoading = false);

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('¡Perfil configurado y Credencial CIVITAS activada con éxito!'),
          backgroundColor: AppColors.successGreen,
        ),
      );

      if (widget.onCompleted != null) {
        widget.onCompleted!(updatedUser);
        return;
      } else {
        // Redirigir a HomeView
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(builder: (_) => HomeView(currentUser: updatedUser)),
          (route) => false,
        );
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _errorMessage = 'Error al finalizar configuración: $e';
      });
    } finally {
      if (mounted && _isLoading && _errorMessage != null) {
        setState(() => _isLoading = false);
      }
    }
  }

  void _showAddCustomContactDialog() {
    final nameCtrl = TextEditingController();
    final phoneCtrl = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Agregar Vecino de Confianza'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: nameCtrl,
              decoration: const InputDecoration(
                labelText: 'Nombre Completo',
                prefixIcon: Icon(Icons.person),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: phoneCtrl,
              keyboardType: TextInputType.phone,
              decoration: const InputDecoration(
                labelText: 'Teléfono Móvil (+569...)',
                prefixIcon: Icon(Icons.phone),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            onPressed: () {
              final name = nameCtrl.text.trim();
              final phone = phoneCtrl.text.trim();
              if (name.isNotEmpty && phone.isNotEmpty) {
                final newContact = TrustedContactEntity(
                  id: 'onboard_custom_${DateTime.now().millisecondsSinceEpoch}',
                  name: name,
                  phone: phone,
                  relationship: 'Vecino de Confianza',
                  isVerified: false,
                  addedAt: DateTime.now(),
                );
                setState(() {
                  _customAddedContacts.add(newContact);
                  _selectedContactIds.add(newContact.id);
                });
                Navigator.pop(ctx);
              }
            },
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary),
            child: const Text('Agregar', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.primaryDark,
        foregroundColor: Colors.white,
        title: const Text(
          'Configuración Inicial CIVITAS',
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
        ),
        elevation: 0,
        centerTitle: true,
      ),
      body: SafeArea(
        child: Column(
          children: [
            // Indicador de pasos superior
            Container(
              color: AppColors.primaryDark,
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
              child: Row(
                children: [
                  _buildStepHeader(0, 'Perfil', Icons.person_pin_rounded),
                  _buildStepDivider(0),
                  _buildStepHeader(1, 'Red de Confianza', Icons.group_add_rounded),
                  _buildStepDivider(1),
                  _buildStepHeader(2, 'Credencial', Icons.verified_user_rounded),
                ],
              ),
            ),

            if (_errorMessage != null)
              Container(
                margin: const EdgeInsets.all(12),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppColors.panicRed.withAlpha(25),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: AppColors.panicRed),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.error_outline, color: AppColors.panicRed),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        _errorMessage!,
                        style: const TextStyle(color: AppColors.panicRed, fontSize: 13),
                      ),
                    ),
                  ],
                ),
              ),

            // Contenido dinámico del paso actual
            Expanded(
              child: _isLoading
                  ? const Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          CircularProgressIndicator(color: AppColors.primary),
                          SizedBox(height: 16),
                          Text('Generando credencial y activando red de confianza...'),
                        ],
                      ),
                    )
                  : SingleChildScrollView(
                      padding: const EdgeInsets.all(20),
                      child: _buildCurrentStepContent(),
                    ),
            ),

            // Barra inferior con controles de navegación
            if (!_isLoading) _buildBottomControls(),
          ],
        ),
      ),
    );
  }

  Widget _buildStepHeader(int step, String title, IconData icon) {
    final isActive = _currentStep == step;
    final isDone = _currentStep > step;

    return Expanded(
      child: Column(
        children: [
          CircleAvatar(
            radius: 16,
            backgroundColor: isDone
                ? AppColors.successGreen
                : (isActive ? Colors.amberAccent : Colors.white24),
            child: Icon(
              isDone ? Icons.check : icon,
              size: 16,
              color: isDone || isActive ? AppColors.primaryDark : Colors.white70,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            title,
            style: TextStyle(
              color: isActive ? Colors.white : Colors.white60,
              fontSize: 10,
              fontWeight: isActive ? FontWeight.bold : FontWeight.normal,
            ),
            textAlign: TextAlign.center,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }

  Widget _buildStepDivider(int step) {
    final isPassed = _currentStep > step;
    return Container(
      width: 24,
      height: 2,
      color: isPassed ? AppColors.successGreen : Colors.white24,
      margin: const EdgeInsets.symmetric(horizontal: 4),
    );
  }

  Widget _buildCurrentStepContent() {
    switch (_currentStep) {
      case 0:
        return _buildStep1Profile();
      case 1:
        return _buildStep2TrustedNetwork();
      case 2:
        return _buildStep3CivitasBadge();
      default:
        return const SizedBox.shrink();
    }
  }

  // PASO 1: Perfil Cívico y Territorial
  Widget _buildStep1Profile() {
    return Form(
      key: _formKeyStep1,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Paso 1: Tu Identidad Cívica',
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: AppColors.primaryDark),
          ),
          const SizedBox(height: 6),
          const Text(
            'Para garantizar la veracidad de los reportes y evitar el anonimato malicioso, completa tus datos oficiales de residencia en Iquique.',
            style: TextStyle(fontSize: 13, color: AppColors.textSecondary),
          ),
          const SizedBox(height: 20),

          TextFormField(
            controller: _nameController,
            decoration: InputDecoration(
              labelText: 'Nombre y Apellido *',
              prefixIcon: const Icon(Icons.person_outline),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
            ),
            validator: (v) => (v == null || v.trim().isEmpty) ? 'El nombre es obligatorio' : null,
          ),
          const SizedBox(height: 14),

          TextFormField(
            controller: _rutController,
            decoration: InputDecoration(
              labelText: 'RUT / DNI (Ej: 18.234.567-K) *',
              prefixIcon: const Icon(Icons.badge_outlined),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
            ),
            validator: (v) => (v == null || v.trim().isEmpty) ? 'El RUT es obligatorio' : null,
          ),
          const SizedBox(height: 14),

          TextFormField(
            controller: _phoneController,
            keyboardType: TextInputType.phone,
            decoration: InputDecoration(
              labelText: 'Teléfono Móvil de Emergencia (+569...) *',
              prefixIcon: const Icon(Icons.phone_outlined),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
            ),
            validator: (v) => (v == null || v.trim().length < 8) ? 'Ingresa un teléfono válido' : null,
          ),
          const SizedBox(height: 14),

          Row(
            children: [
              Expanded(
                child: TextFormField(
                  controller: _cityController,
                  decoration: InputDecoration(
                    labelText: 'Comuna / Ciudad *',
                    prefixIcon: const Icon(Icons.location_city),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                  validator: (v) => (v == null || v.trim().isEmpty) ? 'Indica la ciudad' : null,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: TextFormField(
                  controller: _juntaVecinalController,
                  decoration: InputDecoration(
                    labelText: 'Junta Vecinal / Cuadrante',
                    prefixIcon: const Icon(Icons.holiday_village_outlined),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),

          TextFormField(
            controller: _addressController,
            decoration: InputDecoration(
              labelText: 'Dirección o Pasaje (Ej: Av. Arturo Prat 1230)',
              prefixIcon: const Icon(Icons.home_outlined),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
            ),
          ),
        ],
      ),
    );
  }

  // PASO 2: Selección de Red de Confianza Inicial
  Widget _buildStep2TrustedNetwork() {
    final allDisplayContacts = [..._customAddedContacts, ..._deviceContacts];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Expanded(
              child: Text(
                'Paso 2: Red de Confianza',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: AppColors.primaryDark),
              ),
            ),
            IconButton(
              icon: const Icon(Icons.refresh, color: AppColors.primary),
              tooltip: 'Recargar contactos',
              onPressed: _loadDeviceContacts,
            ),
          ],
        ),
        const SizedBox(height: 6),
        const Text(
          'Selecciona al menos 1 vecino o contacto cercano de tu libreta telefónica. Serán tus primeros guardianes comunitarios.',
          style: TextStyle(fontSize: 13, color: AppColors.textSecondary),
        ),
        const SizedBox(height: 16),

        // Botón para agregar manualmente
        OutlinedButton.icon(
          onPressed: _showAddCustomContactDialog,
          icon: const Icon(Icons.person_add_alt_1),
          label: const Text('Agregar Vecino Manualmente'),
          style: OutlinedButton.styleFrom(
            foregroundColor: AppColors.primary,
            side: const BorderSide(color: AppColors.primary),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          ),
        ),
        const SizedBox(height: 16),

        if (_loadingContacts)
          const Center(
            child: Padding(
              padding: EdgeInsets.all(24),
              child: CircularProgressIndicator(color: AppColors.primary),
            ),
          )
        else if (allDisplayContacts.isEmpty)
          Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                children: [
                  const Icon(Icons.contact_phone_outlined, size: 48, color: AppColors.textSecondary),
                  const SizedBox(height: 12),
                  const Text(
                    'No encontramos contactos en tu teléfono.',
                    style: TextStyle(color: AppColors.textSecondary),
                  ),
                  const SizedBox(height: 8),
                  ElevatedButton(
                    onPressed: _showAddCustomContactDialog,
                    style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary),
                    child: const Text('Ingresar un Contacto Manual', style: TextStyle(color: Colors.white)),
                  ),
                ],
              ),
            ),
          )
        else
          ...allDisplayContacts.map((contact) {
            final isSelected = _selectedContactIds.contains(contact.id);
            return Card(
              margin: const EdgeInsets.only(bottom: 10),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
                side: BorderSide(
                  color: isSelected ? AppColors.primary : Colors.transparent,
                  width: 1.5,
                ),
              ),
              color: isSelected ? AppColors.primary.withAlpha(15) : Colors.white,
              child: CheckboxListTile(
                value: isSelected,
                activeColor: AppColors.primary,
                title: Text(
                  contact.name,
                  style: TextStyle(
                    fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                    color: AppColors.primaryDark,
                  ),
                ),
                subtitle: Text(
                  '${contact.phone} • ${contact.relationship}',
                  style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
                ),
                secondary: CircleAvatar(
                  backgroundColor: isSelected ? AppColors.primary : Colors.grey.shade300,
                  child: Icon(
                    Icons.security,
                    color: isSelected ? Colors.white : Colors.grey.shade700,
                    size: 18,
                  ),
                ),
                onChanged: (checked) {
                  setState(() {
                    if (checked == true) {
                      _selectedContactIds.add(contact.id);
                    } else {
                      _selectedContactIds.remove(contact.id);
                    }
                  });
                },
              ),
            );
          }),
      ],
    );
  }

  // PASO 3: Emisión de Credencial CIVITAS y Compromiso
  Widget _buildStep3CivitasBadge() {
    final folio = 'CIVITAS-CL-${widget.currentUser.uid.length >= 6 ? widget.currentUser.uid.substring(0, 6).toUpperCase() : "SEC2026"}';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Paso 3: Tu Credencial CIVITAS',
          style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: AppColors.primaryDark),
        ),
        const SizedBox(height: 6),
        const Text(
          'Tu credencial digital es tu certificado de pertenencia comunitaria. Se presentará automáticamente al intercambiar confianza con vecinos.',
          style: TextStyle(fontSize: 13, color: AppColors.textSecondary),
        ),
        const SizedBox(height: 20),

        // Credencial visual de seguridad
        CredencialCivitasBadge(
          nombre: _nameController.text.trim().isNotEmpty
              ? _nameController.text.trim()
              : (widget.currentUser.nombre ?? 'Vecino CIVITAS'),
          rut: _rutController.text.trim().isNotEmpty
              ? _rutController.text.trim()
              : widget.currentUser.rut,
          rol: widget.currentUser.rol,
          reputacion: widget.currentUser.reputacion,
          folio: folio,
        ),

        const SizedBox(height: 24),

        // Compromiso ético y legal
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.amber.shade50,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.amber.shade300),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: const [
                  Icon(Icons.gavel_rounded, color: Colors.brown, size: 20),
                  SizedBox(width: 8),
                  Text(
                    'Compromiso Vecinal Anti-Cifra Negra',
                    style: TextStyle(fontWeight: FontWeight.bold, color: Colors.brown),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              const Text(
                'Al ingresar a CIVITAS, te comprometes a utilizar las alertas de pánico y reportes con responsabilidad, protegiendo a tu comunidad y cooperando con juntas vecinales y autoridades.',
                style: TextStyle(fontSize: 12, color: Colors.black87),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Checkbox(
                    value: _acceptedCommitment,
                    activeColor: AppColors.primary,
                    onChanged: (val) => setState(() => _acceptedCommitment = val ?? false),
                  ),
                  const Expanded(
                    child: Text(
                      'Acepto el compromiso cívico y términos de seguridad.',
                      style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildBottomControls() {
    final isLastStep = _currentStep == 2;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withAlpha(15),
            blurRadius: 8,
            offset: const Offset(0, -3),
          ),
        ],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          if (_currentStep > 0)
            OutlinedButton(
              onPressed: () => setState(() => _currentStep--),
              style: OutlinedButton.styleFrom(
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              ),
              child: const Text('Atrás'),
            )
          else
            const SizedBox.shrink(),

          ElevatedButton.icon(
            onPressed: () {
              if (_currentStep == 0) {
                if (_formKeyStep1.currentState?.validate() ?? false) {
                  setState(() => _currentStep = 1);
                }
              } else if (_currentStep == 1) {
                setState(() => _currentStep = 2);
              } else if (isLastStep) {
                _finishOnboarding();
              }
            },
            icon: Icon(
              isLastStep ? Icons.verified : Icons.arrow_forward,
              color: Colors.white,
            ),
            label: Text(
              isLastStep ? 'Activar Credencial e Ingresar' : 'Continuar',
              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
            ),
            style: ElevatedButton.styleFrom(
              backgroundColor: isLastStep ? AppColors.successGreen : AppColors.primary,
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
          ),
        ],
      ),
    );
  }
}
