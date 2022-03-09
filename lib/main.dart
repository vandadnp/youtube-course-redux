import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:redux/redux.dart';
import 'package:flutter_redux/flutter_redux.dart';

void main() {
  runApp(
    MaterialApp(
      title: 'Flutter Demo',
      theme: ThemeData(
        primarySwatch: Colors.blue,
      ),
      debugShowCheckedModeBanner: false,
      home: const HomePage(),
    ),
  );
}

const apiUrl = 'http://127.0.0.1:5501/api/people.json';

@immutable
class Person {
  final String name;
  final int age;

  const Person({
    required this.name,
    required this.age,
  });

  Person.fromJson(Map<String, dynamic> json)
      : name = json['name'] as String,
        age = json['age'] as int;

  @override
  String toString() => 'Person ($name, $age years old)';
}

Future<Iterable<Person>> getPersons() => HttpClient()
    .getUrl(Uri.parse(apiUrl))
    .then((req) => req.close())
    .then((resp) => resp.transform(utf8.decoder).join())
    .then((str) => json.decode(str) as List<dynamic>)
    .then((list) => list.map((e) => Person.fromJson(e)));

@immutable
abstract class Action {
  const Action();
}

@immutable
class LoadPeopleAction extends Action {
  const LoadPeopleAction();
}

@immutable
class SuccessfullyFetchedPeopleAction extends Action {
  final Iterable<Person> persons;
  const SuccessfullyFetchedPeopleAction({required this.persons});
}

@immutable
class FailedToFetchPeopleAction extends Action {
  final Object error;
  const FailedToFetchPeopleAction({required this.error});
}

@immutable
class State {
  final bool isLoading;
  final Iterable<Person>? fetchedPersons;
  final Object? error;

  const State({
    required this.isLoading,
    required this.fetchedPersons,
    required this.error,
  });

  const State.empty()
      : isLoading = false,
        fetchedPersons = null,
        error = null;
}

State reducer(State oldState, action) {
  if (action is LoadPeopleAction) {
    return const State(
      error: null,
      fetchedPersons: null,
      isLoading: true,
    );
  } else if (action is SuccessfullyFetchedPeopleAction) {
    return State(
      error: null,
      fetchedPersons: action.persons,
      isLoading: false,
    );
  } else if (action is FailedToFetchPeopleAction) {
    return State(
      error: action.error,
      fetchedPersons: oldState.fetchedPersons,
      isLoading: false,
    );
  }
  return oldState;
}

void loadPeopleMiddleware(
  Store<State> store,
  action,
  NextDispatcher next,
) {
  if (action is LoadPeopleAction) {
    getPersons().then((persons) {
      store.dispatch(SuccessfullyFetchedPeopleAction(persons: persons));
    }).catchError((e) {
      store.dispatch(FailedToFetchPeopleAction(error: e));
    });
  }
  next(action);
}

class HomePage extends StatelessWidget {
  const HomePage({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final store = Store(
      reducer,
      initialState: const State.empty(),
      middleware: [loadPeopleMiddleware],
    );
    return Scaffold(
      appBar: AppBar(
        title: const Text('Home Page'),
      ),
      body: StoreProvider(
        store: store,
        child: Column(
          children: [
            TextButton(
              onPressed: () {
                store.dispatch(const LoadPeopleAction());
              },
              child: const Text('Load persons'),
            ),
            StoreConnector<State, bool>(
              converter: (store) => store.state.isLoading,
              builder: (context, isLoading) {
                if (isLoading) {
                  return const CircularProgressIndicator();
                } else {
                  return const SizedBox();
                }
              },
            ),
            StoreConnector<State, Iterable<Person>?>(
              converter: (store) => store.state.fetchedPersons,
              builder: (context, people) {
                if (people == null) {
                  return const SizedBox();
                }
                return Expanded(
                  child: ListView.builder(
                    itemCount: people.length,
                    itemBuilder: (context, index) {
                      final person = people.elementAt(index);
                      return ListTile(
                        title: Text(person.name),
                        subtitle: Text('${person.age} years old'),
                      );
                    },
                  ),
                );
              },
            )
          ],
        ),
      ),
    );
  }
}
