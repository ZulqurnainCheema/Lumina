import 'package:lumina/models/books.dart';
import 'package:lumina/services/database_services.dart';

class StreakState {
  const StreakState({
    required this.current,
    required this.longest,
    required this.freezes,
    required this.readToday,
    required this.repairAvailable,
    required this.repairableStreak,
    required this.comeback,
  });

  final int current;
  final int longest;
  final int freezes;
  final bool readToday;

  // Yesterday was missed with no freeze left; doubling today's goal restores it.
  final bool repairAvailable;
  final int repairableStreak;

  // Read today after a break.
  final bool comeback;
}

class TodayData {
  const TodayData({
    required this.streak,
    required this.secondsToday,
    required this.goalMinutes,
    required this.book,
    required this.percentage,
    required this.hook,
    required this.pagesLeft,
    required this.secondsLeft,
    required this.plan,
  });

  final StreakState streak;
  final int secondsToday;
  final int goalMinutes;
  final Books? book;
  final int percentage;
  final String? hook;
  final int? pagesLeft;
  final int? secondsLeft;
  final String? plan;
}

class Celebration {
  const Celebration({
    required this.title,
    required this.body,
    this.big = false,
  });

  final String title;
  final String body;
  final bool big;
}

class HabitServices {
  static final HabitServices instance = HabitServices._constructor();

  HabitServices._constructor();

  static const int maxFreezes = 2;
  static const int daysPerFreeze = 7;
  static const int defaultGoalMinutes = 10;
  static const List<int> streakMilestones = <int>[3, 7, 14, 30, 50, 100, 365];

  final DatabaseServices _databaseServices = DatabaseServices.instance;

  static String dateKey(DateTime date) {
    final String month = date.month.toString().padLeft(2, '0');
    final String day = date.day.toString().padLeft(2, '0');
    return '${date.year}-$month-$day';
  }

  Future<int> getGoalMinutes() {
    return _databaseServices.getIntSetting(
      'dailyGoalMinutes',
      defaultGoalMinutes,
    );
  }

  // Replays every day since the first entry. A day is covered by an entry, a
  // freeze or a repair. Missed days spend a banked freeze, otherwise the
  // streak resets. Safe to call repeatedly.
  Future<StreakState> getStreakState({DateTime? now}) async {
    final DateTime clock = now ?? DateTime.now();
    final DateTime today = DateTime(clock.year, clock.month, clock.day);
    final String todayKey = dateKey(today);
    final String yesterdayKey = dateKey(
      DateTime(today.year, today.month, today.day - 1),
    );

    final Set<String> readDates = await _databaseServices.getReadDates();
    final Map<String, String> events = await _databaseServices
        .getStreakEvents();
    final bool readToday = readDates.contains(todayKey);

    if (readDates.isEmpty) {
      return const StreakState(
        current: 0,
        longest: 0,
        freezes: 0,
        readToday: false,
        repairAvailable: false,
        repairableStreak: 0,
        comeback: false,
      );
    }

    final List<String> sortedDates = readDates.toList()..sort();
    final DateTime first = DateTime.parse(sortedDates.first);

    int streak = 0;
    int longest = 0;
    int freezes = 0;
    int readRun = 0;
    bool repairAvailable = false;
    int repairableStreak = 0;

    for (
      DateTime day = DateTime(first.year, first.month, first.day);
      !day.isAfter(today);
      day = DateTime(day.year, day.month, day.day + 1)
    ) {
      final String key = dateKey(day);
      if (readDates.contains(key)) {
        streak++;
        readRun++;
        if (readRun % daysPerFreeze == 0 && freezes < maxFreezes) {
          freezes++;
        }
        if (streak > longest) {
          longest = streak;
        }
        continue;
      }
      if (key == todayKey) {
        // Today is still open.
        break;
      }
      if (events[key] == 'freeze') {
        if (freezes > 0) {
          freezes--;
        }
        continue;
      }
      if (events[key] == 'repair') {
        continue;
      }
      if (streak == 0) {
        continue;
      }
      if (freezes > 0) {
        freezes--;
        await _databaseServices.addStreakEvent(key, 'freeze');
        continue;
      }
      if (key == yesterdayKey) {
        final int goalSeconds = await getGoalMinutes() * 60;
        final int secondsToday = await _databaseServices.getSecondsOnDate(
          todayKey,
        );
        if (secondsToday >= goalSeconds * 2) {
          await _databaseServices.addStreakEvent(key, 'repair');
          continue;
        }
        repairAvailable = true;
        repairableStreak = streak;
      }
      streak = 0;
      readRun = 0;
    }

    final bool hadEarlierReading = sortedDates.first != todayKey;

    return StreakState(
      current: streak,
      longest: longest,
      freezes: freezes,
      readToday: readToday,
      repairAvailable: repairAvailable,
      repairableStreak: repairableStreak,
      comeback: readToday && streak == 1 && hadEarlierReading,
    );
  }

  Future<TodayData> getToday({DateTime? now}) async {
    final DateTime clock = now ?? DateTime.now();
    final StreakState streak = await getStreakState(now: clock);
    final int secondsToday = await _databaseServices.getSecondsOnDate(
      dateKey(clock),
    );
    final int goalMinutes = await getGoalMinutes();
    final Books? book = await _databaseServices.getCurrentBook();

    int percentage = 0;
    String? hook;
    int? pagesLeft;
    int? secondsLeft;
    if (book != null) {
      percentage = await _databaseServices.getPercentageRead(book.id);
      hook = await _databaseServices.getLatestHook(book.id);
      if (book.totalPages > 0) {
        pagesLeft = (book.totalPages * (100 - percentage) / 100).ceil();
        final double? secondsPerPage = await _databaseServices
            .getSecondsPerPage(book.id);
        if (secondsPerPage != null) {
          secondsLeft = (pagesLeft * secondsPerPage).round();
        }
      }
    }

    return TodayData(
      streak: streak,
      secondsToday: secondsToday,
      goalMinutes: goalMinutes,
      book: book,
      percentage: percentage,
      hook: hook,
      pagesLeft: pagesLeft,
      secondsLeft: secondsLeft,
      plan: await getPlanLine(),
    );
  }

  Future<String?> getPlanLine() async {
    final String cue = (await _databaseServices.getSetting('planCue') ?? '')
        .trim();
    final String place = (await _databaseServices.getSetting('planPlace') ?? '')
        .trim();
    if (cue.isEmpty) {
      return null;
    }
    if (place.isEmpty) {
      return 'After I $cue, I read.';
    }
    return 'After I $cue, I read in $place.';
  }

  // At most one moment per saved entry: the comeback first, then a streak
  // milestone, then a surprise milestone. Each is shown once.
  Future<Celebration?> afterEntry({DateTime? now}) async {
    final DateTime clock = now ?? DateTime.now();
    final String todayKey = dateKey(clock);
    final StreakState streak = await getStreakState(now: clock);

    if (streak.comeback &&
        await _databaseServices.getSetting('comebackShown') != todayKey) {
      await _databaseServices.setSetting('comebackShown', todayKey);
      return const Celebration(
        title: 'You came back.',
        body:
            'Life happened. Coming back after a gap is the part that builds '
            'the habit, and you just did it. Day 1 is yours.',
        big: true,
      );
    }

    final int lastStreakMilestone = await _databaseServices.getIntSetting(
      'streakMilestoneShown',
      0,
    );
    if (streakMilestones.contains(streak.current) &&
        streak.current != lastStreakMilestone) {
      await _databaseServices.setSetting(
        'streakMilestoneShown',
        '${streak.current}',
      );
      return Celebration(
        title: '${streak.current} days in a row',
        body: streak.freezes > 0
            ? 'You have ${streak.freezes} freeze${streak.freezes == 1 ? '' : 's'} banked for the day life gets in the way.'
            : 'Same book, same time tomorrow.',
        big: true,
      );
    }

    return checkMilestones();
  }

  Future<Celebration?> checkMilestones() async {
    final Map<String, int> totals = await _databaseServices.getLifetimeTotals();

    const List<int> pageSteps = <int>[100, 500, 1000, 2500, 5000, 10000, 25000];
    final int pagesShown = await _databaseServices.getIntSetting(
      'milestonePages',
      0,
    );
    final int pageStep = pageSteps.lastWhere(
      (step) => totals['pages']! >= step,
      orElse: () => 0,
    );
    if (pageStep > pagesShown) {
      await _databaseServices.setSetting('milestonePages', '$pageStep');
      return Celebration(
        title: '$pageStep pages',
        body: 'You have now read ${totals['pages']} pages with Lumina.',
      );
    }

    const List<int> hourSteps = <int>[1, 5, 10, 25, 50, 100, 250];
    final int hoursShown = await _databaseServices.getIntSetting(
      'milestoneHours',
      0,
    );
    final int hours = totals['seconds']! ~/ 3600;
    final int hourStep = hourSteps.lastWhere(
      (step) => hours >= step,
      orElse: () => 0,
    );
    if (hourStep > hoursShown) {
      await _databaseServices.setSetting('milestoneHours', '$hourStep');
      return Celebration(
        title: '$hourStep hour${hourStep == 1 ? '' : 's'} in books',
        body: 'That is time you spent inside a book instead of a feed.',
      );
    }

    final int bestSession = await _databaseServices.getIntSetting(
      'milestoneSession',
      0,
    );
    final int longestSession = totals['longestSession']!;
    if (longestSession >= 20 * 60 && longestSession > bestSession) {
      await _databaseServices.setSetting('milestoneSession', '$longestSession');
      if (bestSession > 0) {
        return Celebration(
          title: 'Longest session yet',
          body: '${longestSession ~/ 60} minutes without putting it down.',
        );
      }
    }

    return null;
  }

  static String formatDuration(int seconds) {
    final int hours = seconds ~/ 3600;
    final int minutes = (seconds % 3600) ~/ 60;
    if (hours > 0) {
      return '${hours}h ${minutes}m';
    }
    return '${minutes}m';
  }
}
