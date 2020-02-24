# my-studies.pl

Script για μαζική εισαγωγή βαθμών στο `my-studies.uoa.gr`.

```
perl mystudies.pl [command] [options]

Commands:
    set-grades        Αλλαγή βαθμών
    verify-grades     Έλεγχος ότι οι βαθμοί είναι ίδιοι με το csv αρχείο
    export-grades     Εξαγωγή μη κενών βαθμών στο csv αρχείο
    clear-grades      Αλλαγή όλων των βαθμών σε κενούς

Options:
    --username
    --password
    --course-id       "Κωδικός μαθήματος" από το my-studies
    --grades          csv αρχέιο με βαθμούς. Format: <student-id>,<grade>
    --ignore-missing  Συνέχεια της εκτέλεσης όταν ένα student-id δε βρεθεί στο my-studies
```

__Προσοχή__: o server του `my-studies.uoa.gr` χρησιμοποιεί παλιό TLS το οποίο
δεν υποστηρίζεται σε σύγχρονες διανομές. Το script τρέχει καλά
στο Ubuntu 16.04 που έχουμε στα Linux του τμήματος.