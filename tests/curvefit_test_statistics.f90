! curvefit_test_statistics.f90

module curvefit_test_statistics
    use curvefit_core
    use curvefit_statistics
    implicit none
contains
! ------------------------------------------------------------------------------
    function test_z_value() result(rst)
        ! Local Variables
        logical :: rst
        real(dp) :: c(4), z_ans(4), z
        integer(i32) :: i

        ! Initialization
        rst = .true.
        c = [0.99d0, 0.98d0, 0.95d0, 0.90d0]
        z_ans = [2.576d0, 2.326d0, 1.96d0, 1.645d0]

        ! Compute each z test value
        do i = 1, size(c)
            z = z_value(c(i))
            if (abs(z - z_ans(i)) > 1.0d-3) then
                rst = .false.
                print '(AF5.3AF5.3A)', "Test Failed: Expected a z-value of ", &
                    z_ans(i), ", but computed ", z, "."
                exit
            end if
        end do
    end function

! ------------------------------------------------------------------------------

! ------------------------------------------------------------------------------

! ------------------------------------------------------------------------------
end module
