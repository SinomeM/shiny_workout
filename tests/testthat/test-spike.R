test_that("spike workout survives a YAML round trip", {
  path <- withr::local_tempfile(fileext = ".yaml")
  yaml::write_yaml(spike_workout(), path)
  expect_identical(yaml::read_yaml(path), spike_workout())
})
