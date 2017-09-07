! curvefit_test.f90

! The testing application for the CURVEFIT library.
program main
    use curvefit_test_interp
    use curvefit_test_statistics
    implicit none

    ! Local Variables
    logical :: rst, overall

    ! Initialization
    overall = .true.

    ! Interpolation Tests
    rst = test_linear_interp()
    if (.not.rst) overall = .false.

    rst = test_poly_interp()
    if (.not.rst) overall = .false.

    rst = test_spline_interp()
    if (.not.rst) overall = .false.

    ! Statistics Tests
    rst = test_z_value()
    if (.not.rst) overall = .false.

    rst = test_mean()
    if (.not.rst) overall = .false.

    rst = test_var()
    if (.not.rst) overall = .false.

    rst = test_confidence_interval()
    if (.not.rst) overall = .false.

    rst = test_inc_gamma()
    if (.not.rst) overall = .false.

    rst = test_inc_gamma_comp()
    if (.not.rst) overall = .false.

    rst = test_covariance()
    if (.not.rst) overall = .false.

    rst = test_covariance_2()
    if (.not.rst) overall = .false.

    ! End
    if (overall) then
        print '(A)', "CURVEFIT TEST STATUS: PASS"
    else
        print '(A)', "CURVEFIT TEST STATUS: FAILED"
    end if
end program
