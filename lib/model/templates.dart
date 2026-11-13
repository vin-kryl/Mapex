import 'node.dart';

/// A ready-made starting tree for a new board.
class BoardTemplate {
  const BoardTemplate({
    required this.id,
    required this.title,
    required this.description,
    required this.rootType,
    required this.children,
  });

  final String id;
  final String title;
  final String description;
  final NodeType rootType;
  final List<TemplateStep> children;

  /// The template's tree under [root], with fresh ids from [newId].
  Node fill(Node root, String Function() newId, DateTime now) {
    Node build(TemplateStep s) => Node(
      id: newId(),
      title: s.title,
      type: s.type,
      status: NodeStatus.pending,
      createdAt: now,
      updatedAt: now,
      children: [for (final c in s.children) build(c)],
    );
    return root.copyWith(
      type: rootType,
      children: [for (final c in children) build(c)],
      updatedAt: now,
    );
  }

  static const all = [decision, trip, project, week];

  static const decision = BoardTemplate(
    id: 'decision',
    title: 'Make a decision',
    description: 'Your options, what is good and what worries you',
    rootType: NodeType.decision,
    children: [
      TemplateStep('First option', [
        TemplateStep('What is good about it'),
        TemplateStep('What worries me'),
      ]),
      TemplateStep('Second option', [
        TemplateStep('What is good about it'),
        TemplateStep('What worries me'),
      ]),
      TemplateStep('Third option'),
    ],
  );

  static const trip = BoardTemplate(
    id: 'trip',
    title: 'Plan a trip',
    description: 'Getting there, where to stay, what to do',
    rootType: NodeType.task,
    children: [
      TemplateStep('Getting there', [
        TemplateStep('Compare tickets'),
        TemplateStep('Book tickets'),
      ]),
      TemplateStep.typed('Where to stay', [
        TemplateStep('Hotel'),
        TemplateStep('Apartment'),
      ], type: NodeType.decision),
      TemplateStep('Things to do'),
      TemplateStep('Pack'),
    ],
  );

  static const project = BoardTemplate(
    id: 'project',
    title: 'Launch a project',
    description: 'Plan it, build it, ship it',
    rootType: NodeType.task,
    children: [
      TemplateStep('Plan', [
        TemplateStep('Write down the goal'),
        TemplateStep('List the milestones'),
      ]),
      TemplateStep('Build'),
      TemplateStep('Launch', [
        TemplateStep('Pick a date'),
        TemplateStep('Tell people'),
      ]),
    ],
  );

  static const week = BoardTemplate(
    id: 'week',
    title: 'Weekly goals',
    description: 'A few goals for each part of life',
    rootType: NodeType.task,
    children: [
      TemplateStep('Work'),
      TemplateStep('Health'),
      TemplateStep('Home'),
      TemplateStep('People'),
    ],
  );
}

/// One node of a template, with the steps under it.
class TemplateStep {
  const TemplateStep(this.title, [this.children = const []])
    : type = NodeType.task;

  const TemplateStep.typed(this.title, this.children, {required this.type});

  final String title;
  final List<TemplateStep> children;
  final NodeType type;
}
