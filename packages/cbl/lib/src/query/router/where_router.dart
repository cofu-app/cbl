import '../expressions/expression.dart';
import '../query.dart';
import '../where.dart';

/// Interface for creating and chaining `WHERE` clauses.
// ignore: one_member_abstracts
abstract class WhereRouter {
  /// Creates and returns a `WHERE` clause query component with the given
  /// [expression].
  Where where(ExpressionInterface expression);
}

/// Version of [WhereRouter] for building [SyncQuery]s.
abstract class SyncWhereRouter implements WhereRouter {
  @override
  SyncWhere where(ExpressionInterface expression);
}

/// Version of [WhereRouter] for building [AsyncQuery]s.
abstract class AsyncWhereRouter implements WhereRouter {
  @override
  AsyncWhere where(ExpressionInterface expression);
}
