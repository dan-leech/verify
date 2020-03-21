import 'package:dartz/dartz.dart';
import 'package:equatable/equatable.dart';
import 'package:verify/verify.dart';
import 'package:test/test.dart';
import 'package:meta/meta.dart';

class User extends Equatable {
  final String phone;
  final String mail;
  final int age;

  const User(this.phone, this.mail, this.age);

  @override
  List<Object> get props => [phone, mail, age];
}

class ValidateString {
  static Validator_<String> length(int length,
      {@required ValidationError error}) {
    return Verify.property((s) => s.length == length, error: error);
  }
}

enum ErrorCode {
  userMailEmpty,
  userMailFormat,
  userPhoneEmpty,
  userPhoneFormat,
}

class Error extends ValidationError {
  final String message;

  Error(this.message);

  factory Error.fromCode(ErrorCode code) {
    return Error(_mapCodeToString(code));
  }

  @override
  String get errorDescription => message;

  static String _mapCodeToString(ErrorCode code) {
    switch (code) {
      case ErrorCode.userMailEmpty:
        return 'mail cant be empty';
      case ErrorCode.userMailFormat:
        return 'bad mail format';
      case ErrorCode.userPhoneEmpty:
        return 'phone cant be empty';
      case ErrorCode.userPhoneFormat:
        return 'bad phone format';
      default:
        return '';
    }
  }

  @override
  List<Object> get props => [message];

  @override
  bool get stringify => true;
}

void main() {
  const tUserGood = User('3116419582', 'd.cardona.rojas@gmail.com', 25);
  const tUserBad = User('31123123', 'd.cardona.rojas', 25);

  test(
      'transforming output type of validator does not have effect on failing validator',
      () {
    final errorValidator = Verify.error<User>(Error('validation error'));
    final Validator<User, int> transformedValidator =
        errorValidator.map((_) => 25);
    final result = transformedValidator.verify(tUserGood);
    final result2 = errorValidator.verify(tUserGood);

    final error1 = result.fold((e) => e.first, (_) => Error('1'));
    final error2 = result2.fold((e) => e.first, (_) => Error('2'));
    assert(result.isLeft());
    assert(error1 == error2);
  });

  test('flatmap does not collect both validator errors', () {
    final someUser = User('', '', null);
    final error1 = Error('validation error');
    final error2 = Error('age is required');
    final errorValidator = Verify.error<User>(error1);
    final ageNotNullValidator = Verify.notNull<int>(error2);
    final validator =
        errorValidator.join((user) => ageNotNullValidator.verify(user.age));
    final result = validator.verify(someUser);
    final errors = result.fold((e) => e, (_) => [Error('')]);

    assert(result.isLeft());
    assert(errors.length == 1);
    assert(errors.first == error1);
  });

  test('a >>+= b yields errors of b when a succeeds but b fails', () {
    final someUser = User('', '', null);
    final error2 = Error('age is required');
    final userValidator = Verify.valid<User>(someUser);
    final ageNotNullValidator = Verify.notNull<int>(error2);
    final validator =
        userValidator.join((user) => ageNotNullValidator.verify(user.age));
    final result = validator.verify(someUser);
    final errors = result.fold((e) => e, (_) => [Error('')]);

    assert(result.isLeft());
    assert(errors.length == 1);
    assert(errors.first == error2);
  });

  test(
      'Validator<S,T> >>+= Validator<T, O> returns Validator<S,O> that combines both mappings',
      () {
    final someString = '';
    final countStringLength = Verify.lift((String str) => str.length);
    final greaterThenOne = Verify.lift((int count) => count > 1);
    final validator = countStringLength.join(greaterThenOne);
    final result = validator.verify('123').fold((_) => -1, (v) => v);
    assert(result == true);
  });

  test('Can validate subfield of model with checkProperty method', () {
    const user = User('', '1', 25);

    final userValidator = Verify.empty<User>()
        .check((user) => user.phone.isNotEmpty,
            error: Error.fromCode(ErrorCode.userPhoneEmpty))
        .check((user) => user.mail.isNotEmpty && user.mail.contains('@'),
            error: Error.fromCode(ErrorCode.userMailFormat));

    final result = userValidator.verify(user);
    final errors = result.fold((errors) => errors.length, (_) => 0);
    assert(result.isLeft());
    assert(errors == 2);
  });

  test('Can validate subfield of model with other validator', () {
    const user = User('', '1', 25);

    final emptyStringValidator = Verify.property(
        (String string) => string.isNotEmpty,
        error: Error('string cant be empty'));

    final emailValidator = Verify.property(
        (String email) => email.contains('@'),
        error: Error('email has to contain @'));

    final userValidator = Verify.error<User>(Error('user name not valid'))
        .checkField((user) => user.phone, emptyStringValidator)
        .checkField((user) => user.mail, emailValidator);

    final result = userValidator.verify(user);
    final errors = result.fold((errors) => errors.length, (_) => 0);
    assert(result.isLeft());
    assert(errors == 3);
  });

  test('Can create and run an always succeding validator', () {
    final validator = Verify.valid(tUserGood);
    final result = validator.verify(tUserBad);
    assert(result.isRight());
  });

  test('Can handle errors with onException combinator', () {
    final error = Error('not a proper int');
    final Validator<String, int> intParsingValidator =
        (String str) => Right(int.parse(str));
    final validator = intParsingValidator.onException((_) => error);
    final result = validator.verify('12s');
    final resultError = result.fold((e) => e.first, (v) => Error(''));
    assert(resultError == error);
  });

  test('Can run an error validator to any subject type', () {
    final errorValidator = Verify.error<User>(Error('some errror'));
    final result = errorValidator.verify(tUserGood);
    assert(result.isLeft());
  });

  test('Can transform output of validator', () {
    final stringValidator = Verify.valid<String>('123');
    final intValidator = stringValidator.map((value) => int.tryParse(value));
    final result =
        intValidator.verify('').fold((_) => 0, (parsedValue) => parsedValue);
    assert(result == 123);
  });

  test('Can create and run an always failing validator', () {
    final validator = Verify.error(Error('some error'));
    final result = validator.verify(tUserBad);
    assert(result.isLeft());
  });

  test('Can coerce error to any validator type', () {
    final errorValidator = Verify.error<User>(Error('some errror'));
    final result = errorValidator.verify(tUserGood);
    assert(result.isLeft());
  });

  test('Accumulates errors when running more than one failing validator', () {
    final errorValidator = Verify.error<User>(Error('some errror'));
    final errorValidator2 = Verify.error<User>(Error('some errror'));

    final validator = Verify.all([errorValidator, errorValidator2]);
    final result = validator.verify(tUserBad);

    expect(result, isA<Left>());
    final errorCount = result.fold((l) => l.length, (_) => 0);
    expect(errorCount, 2);
  });

  test('Validator error preserve the order they where added in', () {
    final firstErrorMsg = Error('error1');
    final secondErrorMsg = Error('error2');
    final errorValidator = Verify.error<User>(firstErrorMsg);
    final errorValidator2 = Verify.error<User>(secondErrorMsg);
    final validator = Verify.all([errorValidator, errorValidator2]);
    final result = validator.verify(tUserBad);
    final List<ValidationError> errorMessages =
        result.fold((l) => l, (_) => []);
    expect(errorMessages, [firstErrorMsg, secondErrorMsg]);
  });
}
