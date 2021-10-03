# AutopodDB
Autopods represent rental vehicles. This database stores autopod information and flags user input errors.

The ADB (Autopod Database) utilizes triggers to output an error as defined by the administrator when certain input criteria are not met.
For the scenario, there are entities representing the Autopod, customer, dock station, availability status, rental status, and completed rental.
The triggers include:

-Preventing a user from adding an Autopod to a dock station that is full

-Preventing a user from removing an Autopod that is already rented

-Verifying a user has the correct Autopod ID and correct customer ID

There are also automatic triggers to ensure information following the rental is recorded properly under completed rental. This includes:

-Recording the time an Autopod was rented, and if returned, recording the time of return

-Updating an Autopod that is returned from rental status to available status

-Updating an Autopod that is rented from available status to rental status

-Adding a new Autopod to a dock station with the most available space

All the triggers described above represent real scenarios car rental companies must verify in their own databases. These triggers are applicable
to many other transportation industries, such as aviation, locomotive, and buses. 
