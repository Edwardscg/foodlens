import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/app_theme.dart';
import '../auth/auth_controller.dart';
import '../auth/auth_models.dart';
import 'profile_controller.dart';
import 'profile_models.dart';

class OnboardingPage extends ConsumerStatefulWidget {
  final bool editing;
  const OnboardingPage({super.key, this.editing = false});
  @override
  ConsumerState<OnboardingPage> createState() => _OnboardingPageState();
}

class _OnboardingPageState extends ConsumerState<OnboardingPage> {
  final _dataForm = GlobalKey<FormState>();
  final _targetForm = GlobalKey<FormState>();
  final _age = TextEditingController();
  final _weight = TextEditingController();
  final _height = TextEditingController();
  final _target = TextEditingController();
  String? _name, _sex, _activity, _goal, _error;
  Map<String, String> _errors = {};
  CalorieSuggestion? _suggestion;
  int _step = 0;
  bool _busy = false,
      _manual = false,
      _dirty = false,
      _allowExit = false,
      _confirming = false;
  @override
  void initState() {
    super.initState();
    final saved = ref.read(profileProvider).profile;
    final data = saved?.data;
    _name = data?.name;
    _age.text = data?.age?.toString() ?? '';
    _weight.text = data?.weightKg == null ? '' : profileNumber(data!.weightKg!);
    _height.text = data?.heightCm == null ? '' : profileNumber(data!.heightCm!);
    _sex = data?.sex;
    _activity = data?.activityLevel;
    _goal = data?.goal;
    _target.text = saved?.dailyCalorieGoal?.toString() ?? '';
    // Keep a saved manual goal unless the user explicitly chooses a suggestion.
    _manual = saved?.goalSource == 'MANUAL';
    _step = widget.editing ? 1 : 0;
  }

  @override
  void dispose() {
    _age.dispose();
    _weight.dispose();
    _height.dispose();
    _target.dispose();
    super.dispose();
  }

  ProfileData get _data => ProfileData(
    name: _name,
    age: int.tryParse(_age.text.trim()),
    sex: _sex,
    weightKg: profileDecimal(_weight.text),
    heightCm: profileDecimal(_height.text),
    activityLevel: _activity,
    goal: _goal,
  );
  void _changed(String key) => setState(() {
    _dirty = true;
    _errors.remove(key);
    _error = null;
    _suggestion = null;
    if (!_manual) _target.clear();
  });
  Future<void> _next() async {
    if (_busy) return;
    if (_step == 1) {
      final valid = _dataForm.currentState!.validate();
      if (!sexOptions.containsKey(_sex)) {
        setState(() => _errors['sex'] = 'Selecciona una opción');
        return;
      }
      if (!valid) return;
    }
    if (_step == 2 &&
        (!activityOptions.containsKey(_activity) ||
            !goalOptions.containsKey(_goal))) {
      setState(
        () => _error = 'Selecciona tu actividad y tu objetivo para continuar.',
      );
      return;
    }
    FocusScope.of(context).unfocus();
    setState(() {
      _error = null;
      _step++;
    });
    if (_step == 3) await _suggest();
  }

  Future<void> _suggest() async {
    if (_busy) return;
    setState(() {
      _busy = true;
      _error = null;
      _suggestion = null;
    });
    try {
      final result = await ref.read(profileProvider).suggest(_data);
      if (!mounted) return;
      setState(() {
        _suggestion = result;
        if (result.available && !_manual)
          _target.text = result.calories.toString();
        if (!result.available) _manual = true;
      });
    } on ApiFailure catch (failure) {
      if (mounted)
        setState(() {
          _error = failure.message;
          _errors = failure.fields;
        });
    } catch (_) {
      if (mounted)
        setState(
          () => _error = 'No pudimos calcular la sugerencia. Puedes ingresar una meta manual.',
        );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _save() async {
    if (_busy || _allowExit) return;
    setState(() {
      _error = null;
      _errors = {};
    });
    if (!_targetForm.currentState!.validate()) return;
    if (!_manual && _suggestion?.available != true) {
      setState(
        () => _error = 'Solicita una sugerencia o escribe una meta manual.',
      );
      return;
    }
    setState(() => _busy = true);
    try {
      await ref
          .read(profileProvider)
          .save(_data, suggested: !_manual, target: calorieInput(_target.text));
      if (!mounted) return;
      if (widget.editing) {
        ScaffoldMessenger.of(context)
            .showSnackBar(const SnackBar(content: Text('Perfil guardado')));
        _close();
      } else {
        context.go('/home');
      }
    } on ApiFailure catch (failure) {
      if (!mounted) return;
      setState(() {
        _error = failure.message;
        _errors = failure.fields;
        if (_errors.keys.any(
          (key) => {'age', 'sex', 'weightKg', 'heightCm', 'name'}.contains(key),
        ))
          _step = 1;
        else if (_errors.keys.any(
          (key) => {'activityLevel', 'goal'}.contains(key),
        ))
          _step = 2;
      });
    } catch (_) {
      if (mounted)
        setState(
          () => _error = 'No pudimos confirmar el guardado. Conservamos tus datos para reintentar.',
        );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _close() {
    setState(() => _allowExit = true);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      if (context.canPop()) {
        context.pop();
      } else {
        context.go('/account');
      }
    });
  }

  Future<void> _back() async {
    if (_busy || _confirming) return;
    final first = widget.editing ? 1 : 0;
    if (_step > first) {
      setState(() {
        _step--;
        _error = null;
      });
      return;
    }
    if (widget.editing && !_dirty) {
      _close();
      return;
    }
    _confirming = true;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(
          widget.editing
              ? '¿Salir sin guardar?'
              : '¿Salir de la configuración?',
        ),
        content: Text(
          widget.editing ? 'Los cambios de este formulario no se guardarán.' : 'Se cerrará tu sesión. Podrás completar el perfil al volver a entrar.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Continuar aquí'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Salir'),
          ),
        ],
      ),
    );
    _confirming = false;
    if (!mounted || confirmed != true) return;
    if (widget.editing) {
      _close();
    } else {
      await ref.read(authProvider).logout();
    }
  }

  void _adjust(int change) {
    final current = calorieInput(_target.text);
    if (current == null) return;
    setState(() {
      _target.text = (current + change).clamp(1, 2147483647).toString();
      _manual = true;
      _dirty = true;
      _errors.remove('dailyCalorieGoal');
    });
  }

  @override
  Widget build(BuildContext context) => PopScope(
    canPop: _allowExit,
    onPopInvokedWithResult: (didPop, result) {
      if (!didPop) _back();
    },
    child: Scaffold(
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 560),
            child: ListView(
              padding: const EdgeInsets.fromLTRB(24, 16, 24, 24),
              children: [
                Row(
                  children: [
                    IconButton(
                      tooltip: 'Volver',
                      onPressed: _busy ? null : _back,
                      icon: const Icon(Icons.arrow_back),
                    ),
                    const Spacer(),
                    Chip(
                      avatar: const Icon(
                        Icons.circle,
                        size: 9,
                        color: AppTheme.green,
                      ),
                      label: Text('Paso ${_step + 1} de 4'),
                      side: BorderSide.none,
                      backgroundColor: const Color(0xFFECEEE7),
                    ),
                    const Spacer(),
                    const SizedBox(width: 48),
                  ],
                ),
                const SizedBox(height: 20),
                LinearProgressIndicator(
                  value: (_step + 1) / 4,
                  minHeight: 4,
                  borderRadius: BorderRadius.circular(6),
                  backgroundColor: const Color(0xFFE1E5DC),
                ),
                const SizedBox(height: 28),
                if (_step == 0) ..._intro(context),
                if (_step == 1) ..._personal(context),
                if (_step == 2) ..._activityStep(context),
                if (_step == 3) ..._targetStep(context),
                if (_error != null) ...[
                  const SizedBox(height: 16),
                  Semantics(
                    liveRegion: true,
                    child: Text(
                      _error!,
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.error,
                      ),
                    ),
                  ),
                ],
                const SizedBox(height: 28),
                FilledButton.icon(
                  onPressed: _busy ? null : (_step == 3 ? _save : _next),
                  style: FilledButton.styleFrom(shape: const StadiumBorder()),
                  icon: _busy
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : Icon(
                          _step == 3
                              ? Icons.save_outlined
                              : Icons.arrow_forward,
                        ),
                  label: Text(
                    _busy
                        ? 'Espera un momento…'
                        : _step == 3
                        ? 'Guardar y continuar'
                        : 'Continuar',
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    ),
  );
  Widget _title(BuildContext context, String title, String subtitle) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(title, style: Theme.of(context).textTheme.headlineMedium),
      const SizedBox(height: 12),
      Text(subtitle, style: Theme.of(context).textTheme.bodyLarge),
      const SizedBox(height: 24),
    ],
  );
  List<Widget> _intro(BuildContext context) => [
    Container(
      height: 150,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        gradient: const LinearGradient(
          colors: [Color(0xFFE1E8DD), Color(0xFFF7F8F0)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: const Center(
        child: Icon(Icons.spa_outlined, size: 70, color: AppTheme.green),
      ),
    ),
    const SizedBox(height: 24),
    _title(
      context,
      'Antes de empezar',
      'Smart Food AI ofrece estimaciones nutricionales. Los resultados no sustituyen orientación profesional.',
    ),
    const _InfoBox(
      icon: Icons.tune,
      title: 'Ajuste continuo y personalizado',
      text: 'Usaremos tus datos para proponer una meta diaria que podrás ajustar desde Mi cuenta.',
    ),
    const SizedBox(height: 16),
    const _InfoBox(
      icon: Icons.info_outline,
      title: 'Una referencia orientativa',
      text: 'La estimación es una guía general editable, no una prescripción médica.',
    ),
  ];
  List<Widget> _personal(BuildContext context) => [
    _title(
      context,
      'Configura tu perfil',
      'Introduce tus datos básicos para preparar tu estimación diaria.',
    ),
    Form(
      key: _dataForm,
      autovalidateMode: AutovalidateMode.onUserInteraction,
      child: Column(
        children: [
          TextFormField(
            controller: _age,
            enabled: !_busy,
            keyboardType: TextInputType.number,
            textInputAction: TextInputAction.next,
            decoration: const InputDecoration(
              labelText: 'Edad',
              suffixText: 'años',
            ),
            onChanged: (_) => _changed('age'),
            validator: (value) {
              if (_errors['age'] != null) return _errors['age'];
              final age = int.tryParse((value ?? '').trim());
              return age == null || age < 15 || age > 100
                  ? 'Ingresa una edad entre 15 y 100 años'
                  : null;
            },
          ),
          const SizedBox(height: 8),
          const Align(
            alignment: Alignment.centerLeft,
            child: Text(
              'Años cumplidos. No pedimos fecha de nacimiento.',
              style: TextStyle(fontSize: 12),
            ),
          ),
          const SizedBox(height: 24),
          const Align(
            alignment: Alignment.centerLeft,
            child: Text(
              'Sexo (parámetro de la estimación)',
              style: TextStyle(fontWeight: FontWeight.w600),
            ),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final option in sexOptions.entries)
                ChoiceChip(
                  label: Text(option.value),
                  selected: _sex == option.key,
                  onSelected: _busy
                      ? null
                      : (_) {
                          _changed('sex');
                          setState(() => _sex = option.key);
                        },
                ),
            ],
          ),
          if (_errors['sex'] != null)
            Text(
              _errors['sex']!,
              style: TextStyle(color: Theme.of(context).colorScheme.error),
            ),
          if (_sex == 'OTHER')
            const Padding(
              padding: EdgeInsets.only(top: 8),
              child: Text('Podrás definir tu meta manualmente.'),
            ),
          const SizedBox(height: 24),
          LayoutBuilder(
            builder: (context, constraints) {
              final columns =
                  constraints.maxWidth >= 320 &&
                  MediaQuery.textScalerOf(context).scale(14) <= 20;
              final width = columns
                  ? (constraints.maxWidth - 12) / 2
                  : constraints.maxWidth;
              return Wrap(
                spacing: 12,
                runSpacing: 12,
                children: [
                  SizedBox(
                    width: width,
                    child: _measure(_weight, 'Peso', 'kg', 'weightKg', 30, 300),
                  ),
                  SizedBox(
                    width: width,
                    child: _measure(
                      _height,
                      'Altura',
                      'cm',
                      'heightCm',
                      100,
                      250,
                    ),
                  ),
                ],
              );
            },
          ),
        ],
      ),
    ),
  ];
  Widget _measure(
    TextEditingController controller,
    String label,
    String unit,
    String key,
    int min,
    int max,
  ) => TextFormField(
    controller: controller,
    enabled: !_busy,
    keyboardType: const TextInputType.numberWithOptions(decimal: true),
    textInputAction: TextInputAction.next,
    decoration: InputDecoration(
      labelText: label,
      suffixText: unit,
      errorMaxLines: 3,
    ),
    onChanged: (_) => _changed(key),
    validator: (text) {
      if (_errors[key] != null) return _errors[key];
      final value = profileDecimal(text ?? '');
      return value == null || value < min || value > max
          ? 'Entre $min y $max $unit, hasta 2 decimales'
          : null;
    },
  );
  List<Widget> _activityStep(BuildContext context) => [
    _title(
      context,
      'Tu actividad y tu objetivo',
      'Selecciona las opciones que mejor se adapten a tu día a día.',
    ),
    const _InfoBox(
      icon: Icons.monitor_heart_outlined,
      title: 'Estimación de energía diaria',
      text: 'Revisarás el resultado y podrás elegir una meta manual antes de guardar.',
    ),
    const SizedBox(height: 24),
    const Text(
      'Nivel de actividad · requerido',
      style: TextStyle(fontWeight: FontWeight.bold),
    ),
    const SizedBox(height: 12),
    for (final option in activityOptions.entries)
      _Option(
        title: option.value,
        selected: _activity == option.key,
        onTap: _busy
            ? null
            : () {
                _changed('activityLevel');
                setState(() => _activity = option.key);
              },
      ),
    if (_errors['activityLevel'] != null) Text(_errors['activityLevel']!),
    const SizedBox(height: 20),
    const Text(
      'Objetivo principal · requerido',
      style: TextStyle(fontWeight: FontWeight.bold),
    ),
    const SizedBox(height: 12),
    for (final option in goalOptions.entries)
      _Option(
        title: option.value,
        selected: _goal == option.key,
        onTap: _busy
            ? null
            : () {
                _changed('goal');
                setState(() => _goal = option.key);
              },
      ),
    if (_errors['goal'] != null) Text(_errors['goal']!),
  ];
  List<Widget> _targetStep(BuildContext context) {
    final target = calorieInput(_target.text);
    return [
      _title(
        context,
        'Tu objetivo diario',
        'Revisa tu estimación y confirma la meta que quieras guardar.',
      ),
      _InfoBox(
        icon: Icons.person_outline,
        title: 'PARÁMETROS REGISTRADOS',
        text:
            '${_age.text} años · ${_weight.text} kg · ${_height.text} cm\n${activityOptions[_activity]} · ${goalOptions[_goal]}',
      ),
      const SizedBox(height: 20),
      Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Form(
              key: _targetForm,
              child: TextFormField(
                controller: _target,
                enabled: !_busy,
                keyboardType: TextInputType.number,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                  color: AppTheme.green,
                ),
                decoration: const InputDecoration(
                  labelText: 'Meta diaria',
                  suffixText: 'kcal',
                  errorMaxLines: 3,
                ),
                onChanged: (_) => setState(() {
                  _manual = true;
                  _dirty = true;
                  _error = null;
                  _errors.remove('dailyCalorieGoal');
                }),
                validator: (text) =>
                    _errors['dailyCalorieGoal'] ??
                    (calorieInput(text ?? '') == null
                        ? 'Ingresa una meta diaria válida, mayor que cero'
                        : null),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              _manual ? 'Meta manual' : 'Meta sugerida',
              textAlign: TextAlign.center,
            ),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                IconButton(
                  tooltip: 'Restar 50 kcal',
                  onPressed: _busy || target == null
                      ? null
                      : () => _adjust(-50),
                  icon: const Icon(Icons.remove_circle_outline),
                ),
                const Flexible(
                  child: Text(
                    'Ajusta según tu preferencia',
                    textAlign: TextAlign.center,
                  ),
                ),
                IconButton(
                  tooltip: 'Sumar 50 kcal',
                  onPressed: _busy || target == null ? null : () => _adjust(50),
                  icon: const Icon(Icons.add_circle_outline),
                ),
              ],
            ),
            if (_suggestion != null)
              Text(_suggestion!.message, style: const TextStyle(fontSize: 12)),
            if (_suggestion?.available == true)
              TextButton(
                onPressed: _busy
                    ? null
                    : () => setState(() {
                        _manual = false;
                        _dirty = true;
                        _target.text = _suggestion!.calories.toString();
                        _errors.remove('dailyCalorieGoal');
                      }),
                child: Text('Usar sugerencia: ${_suggestion!.calories} kcal'),
              ),
            if (_suggestion == null && !_busy)
              TextButton(
                onPressed: _suggest,
                child: const Text('Reintentar sugerencia'),
              ),
            const SizedBox(height: 20),
            const Text(
              'Reparto estimado de macronutrientes',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: const SizedBox(
                height: 10,
                child: Row(
                  children: [
                    Expanded(
                      flex: 50,
                      child: ColoredBox(
                        color: AppTheme.blue,
                        child: SizedBox.expand(),
                      ),
                    ),
                    Expanded(
                      flex: 20,
                      child: ColoredBox(
                        color: Color(0xFF925000),
                        child: SizedBox.expand(),
                      ),
                    ),
                    Expanded(
                      flex: 30,
                      child: ColoredBox(
                        color: AppTheme.green,
                        child: SizedBox.expand(),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 12,
              runSpacing: 12,
              children: [
                _Macro(
                  label: 'Carbos',
                  grams: target == null ? null : target * .5 / 4,
                  detail: '50% · 4 kcal/g',
                ),
                _Macro(
                  label: 'Proteína',
                  grams: target == null ? null : target * .2 / 4,
                  detail: '20% · 4 kcal/g',
                ),
                _Macro(
                  label: 'Grasas',
                  grams: target == null ? null : target * .3 / 9,
                  detail: '30% · 9 kcal/g',
                ),
              ],
            ),
            const SizedBox(height: 16),
            const Text(
              'Los macronutrientes son una referencia orientativa, no una prescripción médica.',
              style: TextStyle(fontSize: 12),
            ),
          ],
        ),
      ),
      const SizedBox(height: 20),
      const _InfoBox(
        icon: Icons.tune,
        title: 'Tu meta puede cambiar',
        text: 'Podrás ajustar tus datos y tu meta desde Mi cuenta.',
      ),
    ];
  }
}

class _InfoBox extends StatelessWidget {
  final IconData icon;
  final String title, text;
  const _InfoBox({required this.icon, required this.title, required this.text});
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(
      color: const Color(0xFFEFF1EA),
      borderRadius: BorderRadius.circular(16),
    ),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, color: AppTheme.green),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: const TextStyle(fontWeight: FontWeight.w600)),
              const SizedBox(height: 6),
              Text(text),
            ],
          ),
        ),
      ],
    ),
  );
}

class _Option extends StatelessWidget {
  final String title;
  final bool selected;
  final VoidCallback? onTap;
  const _Option({
    required this.title,
    required this.selected,
    required this.onTap,
  });
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 10),
    child: Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(16),
      clipBehavior: Clip.antiAlias,
      child: Semantics(
        selected: selected,
        button: true,
        child: InkWell(
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(18),
            child: Row(
              children: [
                Icon(
                  selected
                      ? Icons.radio_button_checked
                      : Icons.radio_button_off,
                  color: selected ? AppTheme.green : AppTheme.muted,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    title,
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    ),
  );
}

class _Macro extends StatelessWidget {
  final String label, detail;
  final double? grams;
  const _Macro({
    required this.label,
    required this.grams,
    required this.detail,
  });
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(12),
    decoration: BoxDecoration(
      color: const Color(0xFFF2F4EE),
      borderRadius: BorderRadius.circular(12),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label),
        Text(
          grams == null ? '— g' : '${profileNumber(grams!)} g',
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        Text(detail, style: const TextStyle(fontSize: 11)),
      ],
    ),
  );
}
