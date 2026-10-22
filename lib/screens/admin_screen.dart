import 'package:flutter/material.dart';

import '../main.dart';
import '../services/admin_service.dart';

/// Console de administração: quem pode acessar o app e como está o progresso.
class AdminScreen extends StatefulWidget {
  const AdminScreen({super.key});

  @override
  State<AdminScreen> createState() => _AdminScreenState();
}

class _AdminScreenState extends State<AdminScreen> {
  final _stream = AdminService.members();
  String _query = '';

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return StreamBuilder<List<Member>>(
      stream: _stream,
      builder: (context, snap) {
        if (snap.hasError) {
          return _Message(
            icon: Icons.lock_outline,
            text: 'Não foi possível carregar a lista de acesso.\n${snap.error}',
          );
        }
        if (!snap.hasData) {
          return const Center(child: CircularProgressIndicator());
        }
        final all = snap.data!;
        final q = _query.trim().toLowerCase();
        final members = q.isEmpty
            ? all
            : all
                  .where(
                    (m) =>
                        m.email.contains(q) ||
                        m.label.toLowerCase().contains(q),
                  )
                  .toList();
        final admins = all.where((m) => m.isAdmin).length;
        final neverLogged = all.where((m) => m.lastLoginAt == null).length;

        return ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Administração',
                        style: theme.textTheme.headlineMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        'Só entra no app quem estiver nesta lista, usando a conta Google do e-mail.',
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                Chip(
                  avatar: const Icon(Icons.group_outlined, size: 18),
                  label: Text('${all.length} com acesso'),
                ),
                Chip(
                  avatar: const Icon(Icons.shield_outlined, size: 18),
                  label: Text('$admins administradores'),
                ),
                Chip(
                  avatar: const Icon(Icons.schedule, size: 18),
                  label: Text('$neverLogged ainda não entraram'),
                ),
              ],
            ),
            const SizedBox(height: 16),
            const _AddMemberCard(),
            const SizedBox(height: 16),
            TextField(
              decoration: const InputDecoration(
                prefixIcon: Icon(Icons.search),
                hintText: 'Buscar por nome ou e-mail',
                border: OutlineInputBorder(),
                isDense: true,
              ),
              onChanged: (v) => setState(() => _query = v),
            ),
            const SizedBox(height: 8),
            for (final m in members) _MemberTile(member: m),
            if (members.isEmpty)
              const Padding(
                padding: EdgeInsets.all(24),
                child: Text('Ninguém encontrado.', textAlign: TextAlign.center),
              ),
          ],
        );
      },
    );
  }
}

class _AddMemberCard extends StatefulWidget {
  const _AddMemberCard();

  @override
  State<_AddMemberCard> createState() => _AddMemberCardState();
}

class _AddMemberCardState extends State<_AddMemberCard> {
  final _email = TextEditingController();
  final _name = TextEditingController();
  bool _admin = false;
  bool _saving = false;
  String? _error;

  @override
  void dispose() {
    _email.dispose();
    _name.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final email = _email.text.trim().toLowerCase();
    if (!AdminService.isValidEmail(email)) {
      setState(() => _error = 'Digite um e-mail válido.');
      return;
    }
    setState(() {
      _saving = true;
      _error = null;
    });
    final messenger = ScaffoldMessenger.of(context);
    try {
      final added = await AdminService.add(
        email,
        name: _name.text,
        admin: _admin,
      );
      if (!mounted) return;
      if (!added) {
        setState(() => _error = 'Este e-mail já tem acesso.');
      } else {
        _email.clear();
        _name.clear();
        setState(() => _admin = false);
        messenger.showSnackBar(
          SnackBar(content: Text('Acesso liberado para $email')),
        );
      }
    } catch (e) {
      if (mounted) setState(() => _error = 'Não foi possível salvar: $e');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card.outlined(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('Liberar acesso', style: theme.textTheme.titleMedium),
            const SizedBox(height: 12),
            LayoutBuilder(
              builder: (context, c) {
                final email = TextField(
                  controller: _email,
                  keyboardType: TextInputType.emailAddress,
                  autofillHints: const [AutofillHints.email],
                  decoration: const InputDecoration(
                    labelText: 'E-mail (conta Google)',
                    hintText: 'pessoa@gmail.com',
                    border: OutlineInputBorder(),
                  ),
                  onSubmitted: (_) => _submit(),
                );
                final name = TextField(
                  controller: _name,
                  decoration: const InputDecoration(
                    labelText: 'Nome (opcional)',
                    border: OutlineInputBorder(),
                  ),
                  onSubmitted: (_) => _submit(),
                );
                if (c.maxWidth < 520) {
                  return Column(
                    children: [email, const SizedBox(height: 12), name],
                  );
                }
                return Row(
                  children: [
                    Expanded(flex: 3, child: email),
                    const SizedBox(width: 12),
                    Expanded(flex: 2, child: name),
                  ],
                );
              },
            ),
            const SizedBox(height: 4),
            CheckboxListTile(
              value: _admin,
              onChanged: (v) => setState(() => _admin = v ?? false),
              contentPadding: EdgeInsets.zero,
              controlAffinity: ListTileControlAffinity.leading,
              title: const Text('Administrador'),
              subtitle: const Text(
                'Também pode abrir este console e liberar outras pessoas',
              ),
            ),
            if (_error != null)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Text(
                  _error!,
                  style: TextStyle(color: theme.colorScheme.error),
                ),
              ),
            Align(
              alignment: Alignment.centerRight,
              child: FilledButton.icon(
                onPressed: _saving ? null : _submit,
                icon: _saving
                    ? const SizedBox.square(
                        dimension: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.person_add_alt_1),
                label: const Text('Liberar acesso'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _MemberTile extends StatelessWidget {
  const _MemberTile({required this.member});

  final Member member;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final m = member;
    final me = SyncScope.of(context).user?.email?.toLowerCase() == m.email;
    final photo = m.photoURL;

    return Card.filled(
      margin: const EdgeInsets.symmetric(vertical: 4),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 8, 4, 8),
        child: Row(
          children: [
            CircleAvatar(
              backgroundImage: photo == null ? null : NetworkImage(photo),
              child: photo == null ? Text(m.label[0].toUpperCase()) : null,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Wrap(
                    spacing: 6,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      Text(m.label, style: theme.textTheme.titleSmall),
                      if (m.isOwner)
                        _Badge('Dono', theme.colorScheme.primary)
                      else if (m.isAdmin)
                        _Badge('Admin', theme.colorScheme.tertiary),
                      if (me) _Badge('Você', theme.colorScheme.secondary),
                    ],
                  ),
                  if (m.label != m.email)
                    Text(m.email, style: theme.textTheme.bodySmall),
                  const SizedBox(height: 2),
                  Text(
                    m.lastLoginAt == null
                        ? 'Ainda não entrou'
                        : 'Último acesso: ${_formatDate(m.lastLoginAt!)}',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                  if (m.uid != null) _SummaryLine(uid: m.uid!),
                ],
              ),
            ),
            PopupMenuButton<String>(
              tooltip: 'Opções',
              onSelected: (action) => _onAction(context, action),
              itemBuilder: (context) => [
                const PopupMenuItem(value: 'name', child: Text('Editar nome')),
                // O dono e a própria conta não podem perder o acesso por aqui.
                if (!m.isOwner && !me) ...[
                  PopupMenuItem(
                    value: 'role',
                    child: Text(
                      m.isAdmin
                          ? 'Remover de administrador'
                          : 'Tornar administrador',
                    ),
                  ),
                  const PopupMenuItem(
                    value: 'remove',
                    child: Text('Remover acesso'),
                  ),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _onAction(BuildContext context, String action) async {
    final messenger = ScaffoldMessenger.of(context);
    try {
      if (action == 'role') {
        await AdminService.setAdmin(member.email, !member.isAdmin);
        return;
      }
      if (action == 'name') {
        final name = await showDialog<String>(
          context: context,
          builder: (context) => _EditNameDialog(member: member),
        );
        if (name != null) {
          await AdminService.setName(member.email, name);
          messenger.showSnackBar(
            SnackBar(content: Text('Nome atualizado: ${member.email}')),
          );
        }
        return;
      }
      final ok = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Remover acesso?'),
          content: Text(
            '${member.email} não vai mais conseguir entrar no app. '
            'O progresso dessa pessoa continua guardado caso você libere de novo.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancelar'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Remover'),
            ),
          ],
        ),
      );
      if (ok == true) {
        await AdminService.remove(member.email);
        messenger.showSnackBar(
          SnackBar(content: Text('Acesso removido: ${member.email}')),
        );
      }
    } catch (e) {
      messenger.showSnackBar(SnackBar(content: Text('Não foi possível: $e')));
    }
  }
}

class _EditNameDialog extends StatefulWidget {
  const _EditNameDialog({required this.member});

  final Member member;

  @override
  State<_EditNameDialog> createState() => _EditNameDialogState();
}

class _EditNameDialogState extends State<_EditNameDialog> {
  late final _controller = TextEditingController(
    text: widget.member.name ?? '',
  );

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _save() => Navigator.pop(context, _controller.text);

  @override
  Widget build(BuildContext context) {
    final google = widget.member.displayName;
    return AlertDialog(
      title: const Text('Editar nome'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(widget.member.email),
          const SizedBox(height: 16),
          TextField(
            controller: _controller,
            autofocus: true,
            textCapitalization: TextCapitalization.words,
            decoration: InputDecoration(
              labelText: 'Nome',
              border: const OutlineInputBorder(),
              helperText: google == null
                  ? 'Deixe vazio para usar o nome da conta Google'
                  : 'Deixe vazio para usar o nome do Google ($google)',
            ),
            onSubmitted: (_) => _save(),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancelar'),
        ),
        FilledButton(onPressed: _save, child: const Text('Salvar')),
      ],
    );
  }
}

class _SummaryLine extends StatelessWidget {
  const _SummaryLine({required this.uid});

  final String uid;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return StreamBuilder<ProgressSummary?>(
      stream: AdminService.summary(uid),
      builder: (context, snap) {
        final s = snap.data;
        if (s == null) return const SizedBox.shrink();
        final last = s.lastReviewAt == null
            ? ''
            : ' · estudou ${_formatDate(s.lastReviewAt!)}';
        return Text(
          '${s.seen} vistas · ${s.mastered} dominadas · ${s.due} para revisar · '
          '${s.streak} dias seguidos$last',
          style: theme.textTheme.bodySmall,
        );
      },
    );
  }
}

class _Badge extends StatelessWidget {
  const _Badge(this.text, this.color);

  final String text;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 1),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Text(
        text,
        style: TextStyle(
          color: color,
          fontSize: 11,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }
}

class _Message extends StatelessWidget {
  const _Message({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 40),
            const SizedBox(height: 12),
            Text(text, textAlign: TextAlign.center),
          ],
        ),
      ),
    );
  }
}

String _formatDate(DateTime d) {
  String two(int n) => n.toString().padLeft(2, '0');
  final l = d.toLocal();
  return '${two(l.day)}/${two(l.month)}/${l.year} ${two(l.hour)}:${two(l.minute)}';
}
