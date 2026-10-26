module tests.runner;

import unit_threaded : runTestsMain;

mixin runTestsMain!(
    "storage.catalog.database_catalog",
    "storage.backends.filesystem.backend",
    "storage.backends.filesystem.writer",
    "storage.config.codec",
    "storage.config.configuration_manager",
    "storage.config.options",
    "storage.types.validation.max_length",
    "storage.types.validation.min_length",
    "storage.types.validation.not_empty",
    "storage.types.validation.validator",
);
