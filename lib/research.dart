// The studies each part of Lumina is built on. Shown in the "Why this works"
// sheets and on the Science screen.
class Research {
  const Research({
    required this.key,
    required this.title,
    required this.finding,
    required this.citation,
    this.note,
    this.used = true,
  });

  final String key;
  final String title;
  final String finding;

  // Empty when the feature is a design choice with no study behind it.
  final String citation;

  // Limits of the evidence, said plainly.
  final String? note;

  // False for things Lumina leaves out on purpose.
  final bool used;
}

const List<Research> researchEntries = <Research>[
  Research(
    key: 'tracking',
    title: 'Writing your progress down',
    finding:
        'Across 138 studies and almost 20,000 people, checking progress '
        'against a goal made people more likely to reach it. The effect was '
        'larger when the progress was physically recorded.',
    citation:
        'Harkin et al. (2016). Does monitoring goal progress promote goal '
        'attainment? Psychological Bulletin, 142(2), 198–229.',
  ),
  Research(
    key: 'streak',
    title: 'A streak you can repair',
    finding:
        'In seven experiments, seeing an unbroken streak made people more '
        'likely to keep going, and seeing a broken one made them more likely '
        'to stop, even when what they had actually done was identical. Being '
        'able to repair the streak removed much of that drop. That is why a '
        'missed day can be repaired here, and why any reading at all counts.',
    citation:
        'Silverman & Barasch (2023). On or off track: How (broken) streaks '
        'affect consumer decisions. Journal of Consumer Research, 49(6), '
        '1095–1117.',
  ),
  Research(
    key: 'freeze',
    title: 'Two freezes, and a goal separate from the streak',
    finding:
        'Duolingo tested this on its own learners. Letting people bank two '
        'streak freezes kept more of them active than one, and three were no '
        'better than two. Separating the daily goal from the streak also '
        'brought more people back two weeks later.',
    citation: 'Duolingo product experiments, reported on the Duolingo blog.',
    note: 'Company-reported A/B tests, not peer-reviewed research.',
  ),
  Research(
    key: 'comeback',
    title: 'Coming back is the part that counts',
    finding:
        'A study of 61,293 gym members tested 54 programmes side by side. '
        'The most effective one rewarded people for returning after a missed '
        'workout, raising visits by 27%. So the biggest moment in Lumina is '
        'the first session after a gap.',
    citation:
        'Milkman et al. (2021). Megastudies improve the impact of applied '
        'behavioural science. Nature. doi:10.1038/s41586-021-04128-4',
    note: 'The study measured gym visits, not reading.',
  ),
  Research(
    key: 'plan',
    title: 'If this happens, then I read',
    finding:
        'A review of 94 studies found that people who decide in advance '
        '"when situation X comes up, I will do Y" reach their goals much more '
        'often than people who only intend to.',
    citation:
        'Gollwitzer & Sheeran (2006). Implementation intentions and goal '
        'achievement. Advances in Experimental Social Psychology, 38, 69–119.',
    note: 'Later studies outside the lab find smaller effects.',
  ),
  Research(
    key: 'cue',
    title: 'Habits attach to a moment, not a clock',
    finding:
        'A habit is a link between a context and an action. Once it forms, '
        'the context triggers the action without any decision. The same '
        'place and the same preceding routine, repeated, is what builds it.',
    citation:
        'Wood & Neal (2007). A new look at habits and the habit–goal '
        'interface. Psychological Review, 114(4), 843–863.',
  ),
  Research(
    key: 'hook',
    title: 'Leaving yourself a question',
    finding:
        'Curiosity is the feeling of a specific gap in what you know. '
        'Writing down the question you want answered keeps that gap open '
        'until you read again. In brain-imaging work, being curious engaged '
        'reward circuitry and improved memory for what people then learned.',
    citation:
        'Loewenstein (1994). The psychology of curiosity. Psychological '
        'Bulletin, 116(1), 75–98. Gruber, Gelman & Ranganath (2014). Neuron, '
        '84(2), 486–496.',
  ),
  Research(
    key: 'recall',
    title: 'Remember first, then look',
    finding:
        'Students who recalled a text from memory remembered 61% of it a '
        'week later. Students who reread it several times remembered 40%. '
        'One line written from memory does more than rereading the chapter.',
    citation:
        'Roediger & Karpicke (2006). Test-enhanced learning. Psychological '
        'Science, 17(3), 249–255.',
  ),
  Research(
    key: 'finishLine',
    title: 'Seeing how little is left',
    finding:
        'People speed up as they get close to a goal. Coffee-shop customers '
        'bought more often the nearer they were to a free coffee. Showing '
        'the pages and time left makes the end of a book pull harder.',
    citation:
        'Kivetz, Urminsky & Zheng (2006). The goal-gradient hypothesis '
        'resurrected. Journal of Marketing Research, 43(1), 39–58.',
  ),
  Research(
    key: 'habitStrength',
    title: 'How automatic reading has become',
    finding:
        'These four questions are a validated measure of how automatic a '
        'behaviour is. In the study behind the "66 days" claim, the real '
        'range was 18 to 254 days, and missing a single day made no '
        'measurable difference. Your own line is the honest answer.',
    citation:
        'Gardner et al. (2012). International Journal of Behavioral '
        'Nutrition and Physical Activity. Lally et al. (2010). '
        'European Journal of Social Psychology, 40(6), 998–1009.',
  ),
  Research(
    key: 'freshStart',
    title: 'Mondays and the first of the month',
    finding:
        'People take up goals more often right after a new week, a new '
        'month or a birthday. Gym visits, diet searches and commitments all '
        'rise at those moments. The weekly review uses them to restart.',
    citation:
        'Dai, Milkman & Riis (2014). The fresh start effect. Management '
        'Science, 60(10), 2563–2582.',
    note: 'Observational data; it shows a pattern, not a proven cause.',
  ),
  Research(
    key: 'oneReminder',
    title: 'One reminder a day, then fewer',
    finding:
        'In a six-week trial, activity prompts raised steps by 66% on the '
        'first day. The effect shrank every day and was gone by about day '
        '28. Lumina sends one reminder a day at most, writes it from your '
        'own notes, and backs off when reminders are being ignored.',
    citation:
        'Klasnja et al. (2019). Efficacy of contextually tailored '
        'suggestions for physical activity. Annals of Behavioral Medicine, '
        '53(6), 573.',
    note: 'The trial was about walking, not reading.',
  ),
  Research(
    key: 'dropBook',
    title: 'Dropping a book is allowed',
    finding:
        'A book you are not enjoying can stall everything else. Lumina asks '
        'after a week, lets you drop it, and keeps the pages you read.',
    citation: '',
    note: 'A design choice. No study tests this directly.',
  ),
  Research(
    key: 'noPoints',
    title: 'No points, coins or prizes',
    finding:
        'A review of 128 experiments found that promised rewards for doing '
        'an activity made people less likely to choose it afterwards. '
        'Positive feedback had the opposite effect. Lumina gives you '
        'information about your reading and never pays you for it.',
    citation:
        'Deci, Koestner & Ryan (1999). A meta-analytic review of '
        'experiments examining the effects of extrinsic rewards on '
        'intrinsic motivation. Psychological Bulletin, 125(6), 627–668.',
    used: false,
  ),
  Research(
    key: 'noSlogans',
    title: 'No "you are a reader" slogans',
    finding:
        'A well-known study found that asking people about "being a voter" '
        'instead of "voting" raised turnout. A much larger test found no '
        'effect, so Lumina does not rely on identity wording.',
    citation: 'Bryan et al. (2011), PNAS. Gerber et al. (2016), PNAS.',
    used: false,
  ),
];

Research researchFor(String key) {
  return researchEntries.firstWhere((entry) => entry.key == key);
}
