! curvefit_regression.f90

!> @brief \b curvefit_regression
!!
!! @par Purpose
!! To provide routines for perforing regression operations on sets of numerical
!! data.
module curvefit_regression
    use curvefit_core
    use linalg_sorting, only : sort
    use ferror, only : errors
    implicit none
    private
    public :: lowess_smoothing

! ******************************************************************************
! TYPES
! ------------------------------------------------------------------------------
    !> @brief 
    type lowess_smoothing
        private
        !> N-element array of x data points - sorted into ascending order.
        real(dp), allocatable, dimension(:) :: m_x
        !> N-element array of y data points.
        real(dp), allocatable, dimension(:) :: m_y
        !> N-element array containing the robustness weights for each data 
        !! point.
        real(dp), allocatable, dimension(:) :: m_weights
        !> N-element array containing the residuals (Y - YS)
        real(dp), allocatable, dimension(:) :: m_residuals
        !> Scaling parameter used to define the nature of the linear 
        !! interpolations used by the algorithm.
        real(dp) :: m_delta
        !> Tracks whether or not ls_init has been called
        logical :: m_init = .false.
    contains
        !> @brief Initializes the lowess_smoothing object.
        procedure, public :: initialize => ls_init
        !> @brief Performs the actual smoothing operation.
        procedure, public :: smooth => ls_smooth
    end type

contains
! ******************************************************************************
! LOCAL REGRESSION - LOWESS
! ------------------------------------------------------------------------------
    !> @brief A support routine for the LOWESS library used to compute the 
    !! smoothing of a desired value from a data set.
    !!
    !! @param[in] x An N-element containing the independent variable values of
    !!  the data set.  This array must be in a monotonically increasing order.
    !! @param[in] y  An N-element array of the dependent variables corresponding
    !!  to @p x.
    !! @param[in] xs The value of the independent variable at which the 
    !!  smoothing is computed.
    !! @param[out] ys The fitted value.
    !! @param[in] nleft The index of the first point which should be considered 
    !!  in computing the fit.
    !! @param[in] nright The index of the last point which should be considered 
    !!  in computing the fit.
    !! @param[out] w An N-element array that, on output, contains the weights
    !!  for @p y in the expression for @p ys.
    !! @param[in] userw  If true, a robust fit is carried out using the weights
    !!  in @p rw.  If false, the values in @p rw are not used.
    !! @param[in] rw An N-element array containing the robustness weights.
    !! @param[out] ok Returns true if the calculations were performed; however,
    !!  returns false if the weights are all zero-valued.
    !!
    !! @par Remarks
    !! This routines is an implementation of the LOWEST routine from the LOWESS
    !! library.  A link to this library, along with a basic description of the
    !! algorithm is available 
    !! [here](https://en.wikipedia.org/wiki/Local_regression).  For a detailed
    !! understanding of the algorithm, see the [paper]
    !! (http://www.aliquote.org/cours/2012_biomed/biblio/Cleveland1979.pdf) by
    !! William Cleveland.
    subroutine lowest(x, y, xs, ys, nleft, nright, w, userw, rw, ok)
        ! Arguments
        real(dp), intent(in), dimension(:) :: x, y, rw ! N ELEMENT
        real(dp), intent(in) :: xs
        real(dp), intent(out) :: ys
        integer(i32), intent(in) :: nleft, nright
        real(dp), intent(out), dimension(:) :: w ! N ELEMENT
        logical, intent(in) :: userw
        logical, intent(out) :: ok

        ! Parameters
        real(dp), parameter :: zero = 0.0d0
        real(dp), parameter :: one = 1.0d0
        real(dp), parameter :: p001 = 1.0d-3
        real(dp), parameter :: p999 = 0.999d0

        ! Local Variables
        integer(i32) :: j, n, nrt
        real(dp) :: range, h, h9, h1, a, b, c, r

        ! Initialization
        n = size(x)
        range = x(n) - x(1)
        h = max(xs - x(nleft), x(nright) - xs)
        h9 = p999 * h
        h1 = p001 * h
        a = zero

        ! Process
        do j = nleft, n
            w(j) = zero
            r = abs(x(j) - xs)
            if (r <= h9) then
                if (r > h1) then
                    w(j) = (one - (r / h)**3)**3
                else
                    w(j) = one
                end if
                if (userw) w(j) = rw(j) * w(j)
                a = a + w(j)
            else if (x(j) > xs) then
                exit
            end if
        end do

        nrt = j - 1
        if (a <= zero) then
            ok = .false.
        else
            ok = .true.
            w(nleft:nrt) = w(nleft:nrt) / a
            if (h > zero) then
                a = zero
                do j = nleft, nrt
                    a = a + w(j) * x(j)
                end do
                b = xs - a
                c = zero
                do j = nleft, nrt
                    c = c + w(j) * (x(j) - a)**2
                end do
                if (sqrt(c) > p001 * range) then
                    b = b / c
                    do j = nleft, nrt
                        w(j) = w(j) * (one + b * (x(j) - a))
                    end do
                end if
            end if
            ys = zero
            do j = nleft, nrt
                ys = ys + w(j) * y(j)
            end do
        end if
    end subroutine

! ------------------------------------------------------------------------------
    !> @brief Computes a smoothing of an X-Y data set using a robust locally 
    !! weighted scatterplot smoothing (LOWESS) algorithm.  Fitted values are
    !! computed at each of the supplied x values.
    !!
    !! @param[in] x An N-element containing the independent variable values of
    !!  the data set.  This array must be in a monotonically increasing order.
    !! @param[in] y  An N-element array of the dependent variables corresponding
    !!  to @p x.
    !! @param[in] f Specifies the amount of smoothing.  More specifically, this
    !! value is the fraction of points used to compute each value.  As this 
    !! value increases, the output becomes smoother.  Choosing a value in the
    !! range of 0.2 to 0.8 usually results in a good fit.  As such, a reasonable
    !! starting point, in the absence of better information, is a value of 0.5.
    !! @param[in] nsteps The number of iterations in the robust fit.  If set to
    !!  zero, a nonrobust fit is returned.  Seeting this parameter equal to 2
    !!  should serve most purposes.
    !! @param[in] delta A nonnegative parameter which may be used to save 
    !!  computations.  If N is less than 100, set delta equal to 0.0.  If N is
    !!  larger than 100, set delta = range(x) / k, where k determines the 
    !!  interpolation window used by the linear weighted regression 
    !!  computations.
    !! @param[out] ys An N-element array that, on output, contains the fitted
    !!  values.
    !! @param[out] rw  An N-element array that, on output, contains the 
    !!  robustness weights given to each data point.
    !! @param[out] rs An N-element array that, on output, contains the residual
    !!  @p y - @p ys.
    !!
    !! @par Remarks
    !! This routines is an implementation of the LOWESS routine from the LOWESS
    !! library.  A link to this library, along with a basic description of the
    !! algorithm is available 
    !! [here](https://en.wikipedia.org/wiki/Local_regression).  For a detailed
    !! understanding of the algorithm, see the [paper]
    !! (http://www.aliquote.org/cours/2012_biomed/biblio/Cleveland1979.pdf) by
    !! William Cleveland.
    subroutine lowess(x, y, f, nsteps, delta, ys, rw, res)
        ! Arguments
        real(dp), intent(in), dimension(:) :: x, y
        real(dp), intent(in) :: f
        integer(i32), intent(in) :: nsteps
        real(dp), intent(in) :: delta
        real(dp), intent(out), dimension(:) :: ys, rw, res

        ! Parameters
        real(dp), parameter :: zero = 0.0d0
        real(dp), parameter :: one = 1.0d0
        real(dp), parameter :: three = 3.0d0
        real(dp), parameter :: p001 = 1.0d-3
        real(dp), parameter :: p999 = 0.999d0

        ! Local Variables
        logical :: ok
        integer(i32) :: iter, i, j, n, nleft, nright, ns, last, m1, m2
        real(dp) :: d1, d2, denom, alpha, cut, eps, cmad, c1, c9, r

        ! Initialization
        n = size(x)
        ns = max(min(int(f * real(n, dp), i32), n), 2)
        eps = epsilon(eps)

        ! Quick Return
        if (n < 2) then
            ys = y
            return
        end if

        ! Process
        do iter = 1, nsteps + 1
            nleft = 1
            nright = ns
            last = 0
            i = 1
            do
                do while (nright < n)
                    d1 = x(i) - x(nleft)
                    d2 = x(nright+1) - x(i)
                    if (d1 <= d2) exit
                    nleft = nleft + 1
                    nright = nright + 1
                end do

                call lowest(x, y, x(i), ys(i), nleft, nright, res, iter > 1, &
                    rw, ok)
                if (.not.ok) ys(i) = y(i)
                if (last < i - 1) then
                    denom = x(i) - x(last)
                    do j = last + 1, i - 1
                        alpha = (x(j) - x(last)) / denom
                        ys(j) = alpha * ys(i) + (one - alpha) * ys(last)
                    end do
                end if
                last = i
                cut = x(last) + delta
                do i = last + 1, n
                    if (x(i) > cut) exit
                    if (abs(x(i) - x(last)) < eps) then
                        ys(i) = ys(last)
                        last = i
                    end if
                end do
                i = max(last + 1, i - 1)

                if (last >= n) exit
            end do

            res = y - ys
            if (iter > nsteps) exit
            rw = abs(res)
            call sort(rw, .true.)
            m1 = 1 + n / 2
            m2 = n - m1 + 1
            cmad = three * (rw(m1) + rw(m2))
            c9 = p999 * cmad
            c1 = p001 * cmad
            do i = 1, n
                r = abs(res(i))
                if (r <= c1) then
                    rw(i) = one
                else if (r > c9) then
                    rw(i) = zero
                else
                    rw(i) = (one - (r / cmad)**2)**2
                end if
            end do
        end do
    end subroutine

! ******************************************************************************
! LOWESS_SMOOTHING MEMBERS
! ------------------------------------------------------------------------------
    !> @brief Initializes the lowess_smoothing object.
    !!
    !! @param[in,out] this The lowess_smoothing object.
    !! @param[in] x An N-element containing the independent variable values of
    !!  the data set.  This array must be in a monotonically increasing order.
    !!  The routine is capable of sorting the array into ascending order,
    !!  dependent upon the value of @p srt.  If sorting is performed, this 
    !!  routine will also shuffle @p y to match.
    !! @param[in] y  An N-element array of the dependent variables corresponding
    !!  to @p x.
    !! @param[in] srt An optional flag determining if @p x should be sorted. 
    !!  The default is to sort (true).
    !! @param[out] err An optional errors-based object that if provided can be
    !!  used to retrieve information relating to any errors encountered during
    !!  execution.  If not provided, a default implementation of the errors
    !!  class is used internally to provide error handling.  Possible errors and
    !!  warning messages that may be encountered are as follows.
    !!  - CF_ARRAY_SIZE_ERROR: Occurs if @p x and @p y are not the same size.
    !!  - CF_OUT_OF_MEMORY_ERROR: Occurs if there is insufficient memory
    !!      available.
    subroutine ls_init(this, x, y, srt, err)
        ! Arguments
        class(lowess_smoothing), intent(inout) :: this
        real(dp), intent(in), dimension(:) :: x, y
        logical, intent(in), optional :: srt
        class(errors), intent(inout), optional, target :: err

        ! Parameters
        real(dp), parameter :: zero = 0.0d0

        ! Local Variables
        integer(i32) :: i, n, flag
        integer(i32), allocatable, dimension(:) :: indices
        class(errors), pointer :: errmgr
        type(errors), target :: deferr
        logical :: sortData

        ! Initialization
        this%m_init = .false.
        n = size(x)
        sortData = .true.
        if (present(srt)) sortData = srt
        if (present(err)) then
            errmgr => err
        else
            errmgr => deferr
        end if

        ! Input Check
        if (size(y) /= n) then
            call errmgr%report_error("ls_init", &
                "Input array sizes must match.", CF_ARRAY_SIZE_ERROR)
            return
        end if

        ! Memory Allocations
        if (allocated(this%m_x)) deallocate(this%m_x)
        if (allocated(this%m_y)) deallocate(this%m_y)
        if (allocated(this%m_weights)) deallocate(this%m_weights)
        if (allocated(this%m_residuals)) deallocate(this%m_residuals)
        allocate(this%m_x(n), stat = flag)
        if (flag == 0) allocate(this%m_y(n), stat = flag)
        if (flag == 0) allocate(this%m_weights(n), stat = flag)
        if (flag == 0) allocate(this%m_residuals(n), stat = flag)
        if (flag == 0 .and. sortData) allocate(indices(n), stat = flag)
        if (flag /= 0) then
            call errmgr%report_error("ls_init", &
                "Insufficient memory available.", CF_OUT_OF_MEMORY_ERROR)
            return
        end if

        ! Copy over the data
        if (sortData) then
            do concurrent (i = 1:n)
                this%m_x(i) = x(i)
                indices(i) = i
            end do
            call sort(this%m_x, indices, .true.)
            this%m_y = y(indices)
        else
            do concurrent (i = 1:n)
                this%m_x(i) = x(i)
                this%m_y(i) = y(i)
            end do
        end if

        ! Additional Initialization
        this%m_delta = zero
        if (n > 100) then
        end if
        this%m_init = .true.
    end subroutine

! ------------------------------------------------------------------------------
    !> @brief Performs the actual smoothing operation.
    !!
    !! @param[in,out] this THe lowess_smoothing object.
    !! @param[in] f Specifies the amount of smoothing.  More specifically, this
    !! value is the fraction of points used to compute each value.  As this 
    !! value increases, the output becomes smoother.  Choosing a value in the
    !! range of 0.2 to 0.8 usually results in a good fit.  As such, a reasonable
    !! starting point, in the absence of better information, is a value of 0.5.
    !! @param[out] err
    !!
    !! @return The smoothed data points.
    function ls_smooth(this, f, err) result(ys)
        ! Arguments
        class(lowess_smoothing), intent(inout) :: this
        real(dp), intent(in) :: f
        class(errors), intent(inout), optional, target :: err
        real(dp), allocatable, dimension(:) :: ys

        ! Local Variables
        integer(i32) :: n, flag
        class(errors), pointer :: errmgr
        type(errors), target :: deferr

        ! Input Check
        if (present(err)) then
            errmgr => err
        else
            errmgr => deferr
        end if
        if (.not.this%m_init) then
            ! ERROR
        end if
        n = size(this%m_x)

        ! Process
        allocate(ys(n), stat = flag)
        if (flag /= 0) then
            ! ERROR
            call errmgr%report_error("ls_smooth", &
                "Insufficient memory available.", CF_OUT_OF_MEMORY_ERROR)
            return
        end if
        call lowess(this%m_x, this%m_y, f, 2, this%m_delta, ys, &
            this%m_weights, this%m_residuals)
    end function

! ------------------------------------------------------------------------------

! ------------------------------------------------------------------------------

! ------------------------------------------------------------------------------

! ------------------------------------------------------------------------------

! ------------------------------------------------------------------------------
end module