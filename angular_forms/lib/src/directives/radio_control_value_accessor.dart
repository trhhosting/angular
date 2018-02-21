import 'dart:html';
import 'dart:js_util' as js_util;

import 'package:angular/angular.dart';

import 'control_value_accessor.dart'
    show NG_VALUE_ACCESSOR, ControlValueAccessor;
import 'ng_control.dart' show NgControl;

// TODO: Remove <ControlValueAccessor> after #908 is resolved:
// https://github.com/dart-lang/angular/issues/908
const RADIO_VALUE_ACCESSOR =
    const ExistingProvider<ControlValueAccessor>.forToken(
  NG_VALUE_ACCESSOR,
  RadioControlValueAccessor,
);

/// Internal class used by Angular to uncheck radio buttons with the matching
/// name.
@Injectable()
class RadioControlRegistry {
  final List<dynamic> _accessors = [];
  void add(NgControl control, RadioControlValueAccessor accessor) {
    _accessors.add([control, accessor]);
  }

  void remove(RadioControlValueAccessor accessor) {
    var indexToRemove = -1;
    for (var i = 0; i < _accessors.length; ++i) {
      if (identical(_accessors[i][1], accessor)) {
        indexToRemove = i;
      }
    }
    _accessors.removeAt(indexToRemove);
  }

  void select(RadioControlValueAccessor accessor) {
    for (var c in _accessors) {
      if (identical(c[0].control.root, accessor._control.control.root) &&
          !identical(c[1], accessor)) {
        c[1].fireUncheck();
      }
    }
  }
}

/// The value provided by the forms API for radio buttons.
class RadioButtonState {
  bool checked;
  String value;
  RadioButtonState(this.checked, this.value);
}

/// The accessor for writing a radio control value and listening to changes that
/// is used by the [NgModel], [NgFormControl], and [NgControlName] directives.
///
/// ### Example
///
/// ```dart
/// @Component(
///   template: '''
///     <input type="radio" name="food" [(ngModel)]="foodChicken">
///     <input type="radio" name="food" [(ngModel)]="foodFish">
///   '''
/// )
/// class FoodCmp {
///   RadioButtonState foodChicken = new RadioButtonState(true, "chicken");
///   RadioButtonState foodFish = new RadioButtonState(false, "fish");
/// }
/// ```
@Directive(
  selector: 'input[type=radio][ngControl],'
      'input[type=radio][ngFormControl],'
      'input[type=radio][ngModel]',
  host: const {'(change)': 'changeHandler()', '(blur)': 'touchHandler()'},
  providers: const [RADIO_VALUE_ACCESSOR],
  // TODO(b/71710685): Change to `Visibility.local` to reduce code size.
  visibility: Visibility.all,
)
class RadioControlValueAccessor
    implements ControlValueAccessor, OnDestroy, OnInit {
  HtmlElement _element;
  RadioControlRegistry _registry;
  Injector _injector;
  RadioButtonState _state;
  NgControl _control;
  @Input()
  String name;
  Function _fn;
  void changeHandler() {
    onChange();
  }

  void touchHandler() {
    onTouched();
  }

  void Function() onChange = () {};
  void Function() onTouched = () {};
  RadioControlValueAccessor(this._element, this._registry, this._injector);

  @override
  void ngOnInit() {
    _control = _injector.get(NgControl);
    _registry.add(_control, this);
  }

  @override
  void ngOnDestroy() {
    _registry.remove(this);
  }

  @override
  void writeValue(dynamic value) {
    _state = value;
    if (value?.checked ?? false) {
      js_util.setProperty(_element, 'checked', true);
    }
  }

  @override
  void registerOnChange(dynamic fn(dynamic _)) {
    _fn = fn;
    onChange = () {
      fn(new RadioButtonState(true, _state.value));
      _registry.select(this);
    };
  }

  void fireUncheck() {
    _fn(new RadioButtonState(false, _state.value));
  }

  @override
  void registerOnTouched(dynamic fn()) {
    onTouched = fn;
  }
}
