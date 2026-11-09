import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../auth/domain/entities/user_entity.dart';
import '../../data/datasources/contacts_device_datasource.dart';
import '../../data/datasources/network_remote_datasource.dart';
import '../../data/repositories/network_repository_impl.dart';
import '../../domain/entities/trusted_contact_entity.dart';
import '../../domain/entities/trust_request_entity.dart';
import '../../domain/repositories/network_repository.dart';
import '../widgets/credencial_civitas_badge.dart';

class RedConfianzaScreen extends StatefulWidget {
  final UserEntity currentUser;
  final NetworkRepository? networkRepository;

  const RedConfianzaScreen({
    super.key,
    required this.currentUser,
    this.networkRepository,
  });

  @override
  State<RedConfianzaScreen> createState() => _RedConfianzaScreenState();
}

class _RedConfianzaScreenState extends State<RedConfianzaScreen>
    with SingleTickerProviderStateMixin {
  late final NetworkRepository _repository;
  late final TabController _tabController;
  StreamSubscription<List<TrustRequestEntity>>? _requestsSubscription;

  bool _isLoading = true;
  List<TrustedContactEntity> _trustedContacts = [];
  List<TrustRequestEntity> _pendingRequests = [];
  List<TrustedContactEntity> _deviceContacts = [];
  String _searchFilter = '';

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _repository = widget.networkRepository ??
        NetworkRepositoryImpl(
          remoteDataSource: NetworkRemoteDataSourceImpl(),
          deviceDataSource: ContactsDeviceDataSourceImpl(),
        );

    _loadAllData();
    _initRequestsStream();
  }

  void _initRequestsStream() {
    final phone = widget.currentUser.telefono ?? '';
    if (phone.isNotEmpty) {
      _requestsSubscription = _repository.streamPendingTrustRequests(phone).listen(
        (requests) {
          if (mounted) {
            setState(() {
              _pendingRequests = requests;
            });
          }
        },
        onError: (e) {
          debugPrint('Error en stream de solicitudes: $e');
        },
      );
    }
  }

  @override
  void dispose() {
    _requestsSubscription?.cancel();
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadAllData() async {
    setState(() => _isLoading = true);
    try {
      final contacts = await _repository.getTrustedContacts(widget.currentUser.uid);
      final requests = await _repository.getPendingTrustRequests(widget.currentUser.telefono ?? '');
      final rawDevice = await _repository.getDevicePhoneContacts();
      final device = await _repository.checkRegisteredUsers(rawDevice);

      if (mounted) {
        setState(() {
          _trustedContacts = contacts;
          _pendingRequests = requests;
          _deviceContacts = device;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error al cargar datos de la red: $e'),
            backgroundColor: AppColors.panicRed,
          ),
        );
      }
    }
  }

  Future<void> _handleAcceptRequest(TrustRequestEntity request) async {
    try {
      await _repository.respondTrustRequest(
        requestId: request.id,
        accept: true,
        respondingUser: widget.currentUser,
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('¡Solicitud aceptada! ${request.fromName} se unió a tu Red CIVITAS.'),
            backgroundColor: AppColors.successGreen,
          ),
        );
        _showAcceptedBadgeDialog(request);
        _loadAllData();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error al aceptar solicitud: $e'), backgroundColor: AppColors.panicRed),
        );
      }
    }
  }

  Future<void> _handleRejectRequest(TrustRequestEntity request) async {
    try {
      await _repository.respondTrustRequest(
        requestId: request.id,
        accept: false,
        respondingUser: widget.currentUser,
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Solicitud de ${request.fromName} rechazada.'),
            backgroundColor: AppColors.warningOrange,
          ),
        );
        _loadAllData();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error al rechazar: $e'), backgroundColor: AppColors.panicRed),
        );
      }
    }
  }

  Future<void> _handleSendRequest(String toPhone, String toName) async {
    try {
      await _repository.sendTrustRequest(
        fromUser: widget.currentUser,
        toPhone: toPhone,
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Credencial CIVITAS enviada a $toName ($toPhone).'),
            backgroundColor: AppColors.primary,
          ),
        );
        _loadAllData();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error al enviar solicitud: $e'), backgroundColor: AppColors.panicRed),
        );
      }
    }
  }

  void _handleShareAppInvite(TrustedContactEntity contact) {
    const inviteMessage =
        '¡Hola! Te invito a unirte a CIVITAS, la plataforma comunitaria de seguridad y alerta temprana. Descarga la app y únete a nuestra red vecinal aquí: https://github.com/aunato/civitas/releases/latest';

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Row(
          children: [
            Icon(Icons.share, color: AppColors.primary),
            SizedBox(width: 8),
            Text('Invitar a CIVITAS', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Invita a ${contact.name} (${contact.phone}) a instalar la app para proteger juntos el vecindario:',
              style: const TextStyle(fontSize: 13, color: AppColors.textSecondary),
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.grey.shade100,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.grey.shade300),
              ),
              child: const Text(
                inviteMessage,
                style: TextStyle(fontSize: 12, color: AppColors.textPrimary),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cerrar'),
          ),
          ElevatedButton.icon(
            onPressed: () {
              Clipboard.setData(const ClipboardData(text: inviteMessage));
              Navigator.pop(ctx);
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('Enlace de invitación para ${contact.name} copiado al portapapeles.'),
                  backgroundColor: AppColors.successGreen,
                ),
              );
            },
            icon: const Icon(Icons.copy, size: 16, color: Colors.white),
            label: const Text('Copiar Enlace', style: TextStyle(color: Colors.white)),
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary),
          ),
        ],
      ),
    );
  }

  Future<void> _handleRemoveContact(TrustedContactEntity contact) async {
    // 1. Eliminación instantánea en la interfaz (optimistic UI)
    setState(() {
      _trustedContacts.removeWhere((c) => c.id == contact.id || c.phone == contact.phone);
    });

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('${contact.name} eliminado de la red de confianza.'),
          backgroundColor: AppColors.warningOrange,
          duration: const Duration(seconds: 2),
        ),
      );
    }

    try {
      await _repository.removeTrustedContact(
        userUid: widget.currentUser.uid,
        contactId: contact.id,
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error al eliminar contacto: $e'), backgroundColor: AppColors.panicRed),
        );
        _loadAllData();
      }
    }
  }

  void _showAcceptedBadgeDialog(TrustRequestEntity request) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        contentPadding: const EdgeInsets.all(16),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.verified, color: AppColors.successGreen, size: 48),
            const SizedBox(height: 12),
            const Text(
              '¡Vínculo de Seguridad Confirmado!',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppColors.primaryDark),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 12),
            CredencialCivitasBadge(
              nombre: request.fromName,
              rut: request.fromRut,
              rol: request.fromRol,
              reputacion: request.fromReputacion,
              folio: request.fromCredencialFolio,
            ),
            const SizedBox(height: 16),
            const Text(
              'Este contacto ahora recibirá tus alertas SOS prioritarias y podrá validar incidentes contigo.',
              style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
              textAlign: TextAlign.center,
            ),
          ],
        ),
        actions: [
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            child: const Text('Entendido'),
          ),
        ],
      ),
    );
  }

  void _showManualContactDialog() {
    final nameCtrl = TextEditingController();
    final phoneCtrl = TextEditingController();
    String relationship = 'Vecino de Confianza';

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          title: const Text('Agregar Contacto de Confianza'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nameCtrl,
                decoration: const InputDecoration(
                  labelText: 'Nombre y Apellido',
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
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                value: relationship,
                items: const [
                  DropdownMenuItem(value: 'Vecino de Confianza', child: Text('Vecino de Confianza')),
                  DropdownMenuItem(value: 'Familiar', child: Text('Familiar')),
                  DropdownMenuItem(value: 'Comité de Seguridad', child: Text('Comité de Seguridad')),
                ],
                onChanged: (val) {
                  if (val != null) setDialogState(() => relationship = val);
                },
                decoration: const InputDecoration(
                  labelText: 'Parentesco / Vínculo',
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
              onPressed: () async {
                final name = nameCtrl.text.trim();
                final phone = phoneCtrl.text.trim();
                if (name.isEmpty || phone.isEmpty) return;

                Navigator.pop(ctx);
                final newContact = TrustedContactEntity(
                  id: 'c_${DateTime.now().millisecondsSinceEpoch}',
                  name: name,
                  phone: phone,
                  relationship: relationship,
                  isVerified: false,
                  addedAt: DateTime.now(),
                );

                await _repository.addTrustedContact(
                  userUid: widget.currentUser.uid,
                  contact: newContact,
                );
                await _handleSendRequest(phone, name);
                _loadAllData();
              },
              style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary),
              child: const Text('Guardar e Invitar', style: TextStyle(color: Colors.white)),
            ),
          ],
        ),
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
          'Red de Confianza CIVITAS',
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
        ),
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: Colors.amberAccent,
          indicatorWeight: 3,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white60,
          tabs: [
            Tab(
              icon: const Icon(Icons.people_alt_rounded),
              text: 'Mi Red (${_trustedContacts.length})',
            ),
            Tab(
              icon: Stack(
                clipBehavior: Clip.none,
                children: [
                  const Icon(Icons.mark_email_unread_rounded),
                  if (_pendingRequests.isNotEmpty)
                    Positioned(
                      right: -6,
                      top: -4,
                      child: Container(
                        padding: const EdgeInsets.all(4),
                        decoration: const BoxDecoration(
                          color: AppColors.panicRed,
                          shape: BoxShape.circle,
                        ),
                        child: Text(
                          '${_pendingRequests.length}',
                          style: const TextStyle(fontSize: 10, color: Colors.white, fontWeight: FontWeight.bold),
                        ),
                      ),
                    ),
                ],
              ),
              text: 'Solicitudes',
            ),
            const Tab(
              icon: Icon(Icons.contacts_rounded),
              text: 'Contactos',
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'Actualizar Red',
            onPressed: _loadAllData,
          ),
          IconButton(
            icon: const Icon(Icons.badge_rounded),
            tooltip: 'Mi Credencial',
            onPressed: () {
              showModalBottomSheet(
                context: context,
                backgroundColor: Colors.transparent,
                builder: (_) => Container(
                  padding: const EdgeInsets.all(20),
                  child: CredencialCivitasBadge(
                    nombre: widget.currentUser.nombre ?? 'Vecino CIVITAS',
                    rut: widget.currentUser.rut,
                    rol: widget.currentUser.rol,
                    reputacion: widget.currentUser.reputacion,
                    folio: 'CIVITAS-CL-${widget.currentUser.uid.length >= 6 ? widget.currentUser.uid.substring(0, 6).toUpperCase() : "SEC2026"}',
                  ),
                ),
              );
            },
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _showManualContactDialog,
        backgroundColor: AppColors.primary,
        icon: const Icon(Icons.person_add, color: Colors.white),
        label: const Text('Agregar Manual', style: TextStyle(color: Colors.white)),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: AppColors.primary))
          : TabBarView(
              controller: _tabController,
              children: [
                _buildTrustedContactsTab(),
                _buildPendingRequestsTab(),
                _buildDeviceContactsTab(),
              ],
            ),
    );
  }

  Widget _buildTrustedContactsTab() {
    final hasRequests = _pendingRequests.isNotEmpty;

    if (_trustedContacts.isEmpty && !hasRequests) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.shield_outlined, size: 72, color: AppColors.primary.withAlpha(120)),
              const SizedBox(height: 16),
              const Text(
                'Aún no tienes contactos en tu Red de Confianza',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.primaryDark),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              const Text(
                'Agrega vecinos de tu cuadra o familiares. Ellos serán notificados inmediatamente ante emergencias SOS.',
                style: TextStyle(fontSize: 13, color: AppColors.textSecondary),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 24),
              ElevatedButton.icon(
                onPressed: () => _tabController.animateTo(2),
                icon: const Icon(Icons.contacts, color: Colors.white),
                label: const Text('Explorar Contactos del Teléfono', style: TextStyle(color: Colors.white)),
                style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary),
              ),
            ],
          ),
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      itemCount: _trustedContacts.length + (hasRequests ? 1 : 0),
      itemBuilder: (context, index) {
        if (hasRequests && index == 0) {
          return Container(
            margin: const EdgeInsets.only(bottom: 12),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.amber.shade50,
              border: Border.all(color: Colors.amber.shade600, width: 1.5),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              children: [
                const Icon(Icons.mark_email_unread_rounded, color: Colors.amber, size: 28),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '${_pendingRequests.length} Solicitud(es) de Confianza',
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: AppColors.primaryDark),
                      ),
                      const Text(
                        'Vecinos esperando vincular sus credenciales de seguridad.',
                        style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
                      ),
                    ],
                  ),
                ),
                TextButton(
                  onPressed: () => _tabController.animateTo(1),
                  child: const Text('Revisar', style: TextStyle(fontWeight: FontWeight.bold)),
                ),
              ],
            ),
          );
        }

        final contactIndex = hasRequests ? index - 1 : index;
        final contact = _trustedContacts[contactIndex];
        return Card(
          margin: const EdgeInsets.only(bottom: 12),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          elevation: 2,
          child: ListTile(
            leading: CircleAvatar(
              backgroundColor: contact.isVerified ? AppColors.successGreen : AppColors.primaryLight,
              child: Icon(
                contact.isVerified ? Icons.verified_user : Icons.person,
                color: Colors.white,
              ),
            ),
            title: Row(
              children: [
                Expanded(
                  child: Text(
                    contact.name,
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                  ),
                ),
                if (contact.isVerified)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: AppColors.successGreen.withAlpha(30),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: const Text(
                      'CIVITAS',
                      style: TextStyle(
                        color: AppColors.successGreen,
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
              ],
            ),
            subtitle: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 4),
                Text(
                  contact.phone,
                  style: const TextStyle(color: AppColors.textPrimary, fontSize: 13),
                ),
                Text(
                  contact.relationship,
                  style: const TextStyle(color: AppColors.textSecondary, fontSize: 12),
                ),
              ],
            ),
            trailing: IconButton(
              icon: const Icon(Icons.delete_outline, color: AppColors.panicRed),
              tooltip: 'Eliminar contacto',
              onPressed: () => _handleRemoveContact(contact),
            ),
          ),
        );
      },
    );
  }

  Widget _buildPendingRequestsTab() {
    if (_pendingRequests.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: const [
              Icon(Icons.mark_email_read_outlined, size: 72, color: AppColors.successGreen),
              SizedBox(height: 16),
              Text(
                'No tienes solicitudes pendientes',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.primaryDark),
              ),
              SizedBox(height: 8),
              Text(
                'Cuando un vecino te invite a su red de seguridad con su Credencial CIVITAS, aparecerá aquí.',
                style: TextStyle(fontSize: 13, color: AppColors.textSecondary),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      itemCount: _pendingRequests.length,
      itemBuilder: (context, index) {
        final req = _pendingRequests[index];
        return Card(
          margin: const EdgeInsets.only(bottom: 16),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          elevation: 3,
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const CircleAvatar(
                      backgroundColor: AppColors.primary,
                      child: Icon(Icons.shield_rounded, color: Colors.white),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            req.fromName,
                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                          ),
                          Text(
                            'Tel: ${req.fromPhone} • Rol: ${req.fromRol}',
                            style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                // Tarjeta de Credencial Oficial presentada por el emisor
                CredencialCivitasBadge(
                  nombre: req.fromName,
                  rut: req.fromRut,
                  rol: req.fromRol,
                  reputacion: req.fromReputacion,
                  folio: req.fromCredencialFolio,
                  isCompact: false,
                ),
                const SizedBox(height: 16),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    OutlinedButton(
                      onPressed: () => _handleRejectRequest(req),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppColors.panicRed,
                        side: const BorderSide(color: AppColors.panicRed),
                      ),
                      child: const Text('Rechazar'),
                    ),
                    const SizedBox(width: 12),
                    ElevatedButton.icon(
                      onPressed: () => _handleAcceptRequest(req),
                      icon: const Icon(Icons.check_circle_outline, color: Colors.white),
                      label: const Text('Aceptar Credencial', style: TextStyle(color: Colors.white)),
                      style: ElevatedButton.styleFrom(backgroundColor: AppColors.successGreen),
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

  Widget _buildDeviceContactsTab() {
    final filteredContacts = _deviceContacts.where((c) {
      if (_searchFilter.isEmpty) return true;
      return c.name.toLowerCase().contains(_searchFilter.toLowerCase()) ||
          c.phone.contains(_searchFilter);
    }).toList();

    // Priorizar contactos que ya tienen cuenta CIVITAS (estilo WhatsApp)
    filteredContacts.sort((a, b) {
      if (a.isRegisteredInCivitas == b.isRegisteredInCivitas) {
        return a.name.toLowerCase().compareTo(b.name.toLowerCase());
      }
      return a.isRegisteredInCivitas ? -1 : 1;
    });

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
          child: TextField(
            decoration: InputDecoration(
              hintText: 'Buscar en libreta de contactos...',
              prefixIcon: const Icon(Icons.search),
              suffixIcon: _searchFilter.isNotEmpty
                  ? IconButton(
                      icon: const Icon(Icons.clear),
                      onPressed: () => setState(() => _searchFilter = ''),
                    )
                  : null,
              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
            ),
            onChanged: (val) => setState(() => _searchFilter = val),
          ),
        ),
        Expanded(
          child: filteredContacts.isEmpty
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: const [
                        Icon(Icons.person_search_rounded, size: 56, color: AppColors.textSecondary),
                        SizedBox(height: 12),
                        Text(
                          'No se encontraron contactos en tu dispositivo',
                          style: TextStyle(color: AppColors.textSecondary),
                        ),
                      ],
                    ),
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  itemCount: filteredContacts.length,
                  itemBuilder: (context, index) {
                    final contact = filteredContacts[index];
                    final alreadyInNetwork = _trustedContacts.any((c) => c.phone == contact.phone);

                    return Card(
                      margin: const EdgeInsets.only(bottom: 8),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      child: ListTile(
                        leading: CircleAvatar(
                          backgroundColor: contact.isRegisteredInCivitas
                              ? AppColors.primary
                              : AppColors.primary.withAlpha(40),
                          child: Text(
                            contact.name.isNotEmpty ? contact.name[0].toUpperCase() : '?',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              color: contact.isRegisteredInCivitas ? Colors.white : AppColors.primary,
                            ),
                          ),
                        ),
                        title: Row(
                          children: [
                            Expanded(
                              child: Text(
                                contact.name,
                                style: const TextStyle(fontWeight: FontWeight.w600),
                              ),
                            ),
                            if (contact.isRegisteredInCivitas)
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                decoration: BoxDecoration(
                                  color: AppColors.successGreen.withAlpha(30),
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: const Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(Icons.verified, size: 12, color: AppColors.successGreen),
                                    SizedBox(width: 2),
                                    Text(
                                      'En CIVITAS',
                                      style: TextStyle(
                                        color: AppColors.successGreen,
                                        fontSize: 10,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                          ],
                        ),
                        subtitle: Text(contact.phone, style: const TextStyle(fontSize: 12)),
                        trailing: alreadyInNetwork
                            ? const Chip(
                                label: Text(
                                  'En tu Red',
                                  style: TextStyle(fontSize: 10, color: AppColors.successGreen),
                                ),
                                backgroundColor: Color(0xFFE8F5E9),
                              )
                            : contact.isRegisteredInCivitas
                                ? ElevatedButton.icon(
                                    onPressed: () => _handleSendRequest(contact.phone, contact.name),
                                    icon: const Icon(Icons.person_add, size: 14, color: Colors.white),
                                    label: const Text('Agregar a Red', style: TextStyle(fontSize: 11, color: Colors.white)),
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: AppColors.primary,
                                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                      minimumSize: Size.zero,
                                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                    ),
                                  )
                                : OutlinedButton.icon(
                                    onPressed: () => _handleShareAppInvite(contact),
                                    icon: const Icon(Icons.share, size: 14, color: AppColors.primary),
                                    label: const Text('Invitar', style: TextStyle(fontSize: 11, color: AppColors.primary)),
                                    style: OutlinedButton.styleFrom(
                                      side: const BorderSide(color: AppColors.primary),
                                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                      minimumSize: Size.zero,
                                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                    ),
                                  ),
                      ),
                    );
                  },
                ),
        ),
      ],
    );
  }
}
