const sexOptions = {
  'F': 'Femenino',
  'M': 'Masculino',
  'OTHER': 'Otra opción / Prefiero no indicarlo',
};
const activityOptions = {
  'sedentary': 'Poco activo',
  'light': 'Actividad ligera',
  'moderate': 'Actividad moderada',
  'active': 'Actividad alta',
  'very_active': 'Muy activo',
};
const goalOptions = {
  'lose': 'Perder peso',
  'maintain': 'Mantener peso',
  'gain': 'Ganar peso',
  'improve_habits': 'Mejorar hábitos',
};

class ProfileData {
  final String? name, sex, activityLevel, goal;
  final int? age;
  final double? weightKg, heightCm;
  const ProfileData({
    this.name,
    this.age,
    this.sex,
    this.weightKg,
    this.heightCm,
    this.activityLevel,
    this.goal,
  });
  factory ProfileData.fromJson(Map<String, dynamic> json) => ProfileData(
    name: json['name'] as String?,
    age: json['age'] as int?,
    sex: json['sex'] as String?,
    weightKg: (json['weightKg'] as num?)?.toDouble(),
    heightCm: (json['heightCm'] as num?)?.toDouble(),
    activityLevel: json['activityLevel'] as String?,
    goal: json['goal'] as String?,
  );
  Map<String, dynamic> toJson() => {
    'name': name,
    'age': age,
    'sex': sex,
    'weightKg': weightKg,
    'heightCm': heightCm,
    'activityLevel': activityLevel,
    'goal': goal,
  };
  bool get valid =>
      age != null &&
      age! >= 15 &&
      age! <= 100 &&
      sexOptions.containsKey(sex) &&
      weightKg != null &&
      weightKg!.isFinite &&
      weightKg! >= 30 &&
      weightKg! <= 300 &&
      heightCm != null &&
      heightCm!.isFinite &&
      heightCm! >= 100 &&
      heightCm! <= 250 &&
      activityOptions.containsKey(activityLevel) &&
      goalOptions.containsKey(goal);
}

class UserProfile {
  final bool completed;
  final ProfileData data;
  final int? dailyCalorieGoal;
  final String? goalSource;
  const UserProfile(
    this.completed,
    this.data,
    this.dailyCalorieGoal,
    this.goalSource,
  );
  factory UserProfile.fromJson(Map<String, dynamic> json) {
    final completed = json['completed'] as bool;
    final data = ProfileData.fromJson(
      Map<String, dynamic>.from(json['profile'] as Map),
    );
    final target = json['dailyCalorieGoal'] as int?;
    final source = json['goalSource'] as String?;
    if (completed &&
        (!data.valid ||
            target == null ||
            target <= 0 ||
            !{'MANUAL', 'SUGGESTED'}.contains(source))) {
      throw const FormatException('Invalid completed profile');
    }
    return UserProfile(completed, data, target, source);
  }
}

class CalorieSuggestion {
  final bool available;
  final int? calories;
  final String message;
  const CalorieSuggestion(this.available, this.calories, this.message);
  factory CalorieSuggestion.fromJson(Map<String, dynamic> json) {
    final available = json['available'] as bool;
    final calories = json['calories'] as int?;
    if (available && (calories == null || calories <= 0)) {
      throw const FormatException('Invalid suggestion');
    }
    return CalorieSuggestion(available, calories, json['message'] as String);
  }
}

double? profileDecimal(String text) {
  final input = text.trim().replaceAll(',', '.');
  if (!RegExp(r'^\d{1,3}(\.\d{1,2})?$').hasMatch(input)) return null;
  return double.tryParse(input);
}

int? calorieInput(String text) {
  final input = text.trim();
  if (!RegExp(r'^\d{1,10}$').hasMatch(input)) return null;
  final value = int.tryParse(input);
  return value != null && value > 0 && value <= 2147483647 ? value : null;
}

String profileNumber(num value) => value
    .toStringAsFixed(2)
    .replaceFirst(RegExp(r'\.?0+$'), '')
    .replaceAll('.', ',');
