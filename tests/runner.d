module tests.runner;

import unit_threaded : runTestsMain;

mixin runTestsMain!(
    "storage.catalog.database_catalog",
    "storage.types.validation.max_length",
    "storage.types.validation.min_length",
    "storage.types.validation.not_empty",
    "storage.types.validation.validator",
);
