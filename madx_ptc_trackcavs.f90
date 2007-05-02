module madx_ptc_trackline_module
  use madx_ptc_module
  use madx_ptc_intstate_module 
  use madx_ptc_setcavs_module
  implicit none
  save
  public

  public                              :: ptc_trackline       ! subroutine inside the module
  public                              :: ptc_track_everystep
  
  ! flag for debugging ranges from 0 (no debug printout) to 10 (the most detailed)
  real(dp),allocatable :: Dismom(:,:)    ! <xnormal_(2*i-1)**(2j)>= dismon(i,j)*I_i**j
  private filter
  private my_nd_for_averaging
  integer:: my_nd_for_averaging=2
  ! external c-functions
  ! double precision, external :: get_value    ! double get_value(char* name, char* par)
  ! double precision, external :: get_variable ! double get_variable(char* name)
  ! integer,          external :: get_option   ! int get_option(char*);

  !********************************************************************************************
  !********************************************************************************************
  !********************************************************************************************

contains

  subroutine ptc_track_everystep(nobs)
    ! subroutine that performs tracking with acceleration
    ! it is called as a result of ptc_trackline MAD-X command

    implicit none
    integer, intent (IN) :: nobs ! the maximum number of observation points >=1
    INTEGER, ALLOCATABLE :: observedelements(:)
    integer  :: charge    ! charge of an accelerated particle
    type(fibre), pointer :: p
    real (dp)            :: x(1:6)
    !    real (dp)            :: polarx(1:6)   ! track vector -
    real (dp)            :: xp, yp, pz, p0
    real (dp)            :: pathlegth = zero
    integer              :: npart = 1
    integer              :: n = 1
    integer              :: nturns = 1
    integer              :: t = 1
    logical(lp)          :: gcs
    logical(lp)          :: rplot
    real (dp)            :: gposx, gposy, gposz
    integer              :: e, ni
    integer              :: apertflag
    character(200)       :: whymsg
    integer              :: why(9)
    !    integer              :: rplotno
    integer              :: obspointnumber ! observation point number in c-code
    integer              :: getnumberoftracks !function
    type(internal_state)  :: intstate
    real(kind(1d0))      :: get_value,get_variable
    integer, external    :: get_option, &   !  int get_option(char*);
         restart_sequ, & !  restart beamline and return number of beamline node
         advance_node    !  advance to the next node in expanded sequence
    !                    !  =0 (end of range), =1 (else)
    REAL(KIND(1d0)), external :: node_value  !/*returns value for parameter par of current element */
    TYPE(BEAM) :: TheBEAM
    TYPE(INTEGRATION_NODE),POINTER :: CURR_SLICE,PREV_SLICE

    
    !------------------------------------------------------
    !initialization
    npart = 1
    n = 1
    t = 1
    !------------------------------------------------------

    if(universe.le.0) then
       call fort_warn('return from ptc_trackline: ',' no universe created')
       return
    endif
    if(index.le.0) then
       call fort_warn('return from ptc_trackline: ',' no layout created')
       return
    endif

    nturns = get_value('ptc_trackline ','turns ')
    if (getdebug() > 2) print *, 'ptc_trackline, nturns = ', nturns

    if ( (nturns > 1) .and. (my_ring%closed .eqv. .false.)) then
       call fort_warn('WARNING: You can not make more than one turn in a line!', &
            'Putting number of turns to 1!')
       nturns = 1
    endif


    gcs = get_value('ptc_trackline ','gcs ') .ne. 0

    rplot = get_value('ptc_trackline ','rootntuple ') .ne. 0
    
    intstate = getintstate()
    if (gcs .and.  intstate%TOTALPATH) then
       call fort_warn("ptc_trackline","Having global coordinates and totalpath for z is sensless")
       gcs = .false.
    endif


    allocate(observedelements(1:my_ring%n)); observedelements(:)=0 ! zero means that this element is not an obs. point

    c_%x_prime=.true.

    e=restart_sequ()
    p=>my_ring%start
    do e=1, my_ring%n

       obspointnumber=node_value('obs_point ')
       IF (e.eq.1) obspointnumber=1 ! node_value gives 0 for 1st (?)

       if (obspointnumber .gt. 0) then
          if (getdebug() > 0) print *,"Element ",e," is an observation point no. ",obspointnumber
          observedelements(e) = obspointnumber
       endif

       obspointnumber=advance_node() ! c-code go to the next node -> the passed value is never used, just to shut up a compiler
       p=>p%next
    enddo


    charge = get_value('beam ', "charge ");
    if (getdebug() > 3 ) print *, 'Read charge:', charge,' layout has charge ', my_ring%charge

    if (cavsareset .eqv. .false.) then
       call setcavities(my_ring,maxaccel)
    endif

    if (getdebug() > 0) print *, 'reading tracks starting posiotions from table ....'

    call gettrack(1,x(1),x(2),x(3),x(4),x(6),x(5))

    if (getdebug() > 0) print *, 'reading.... Done'

    if (getdebug() > 0) then
       print *, '###################################################'
       print *, '###################################################'
       print *, '######         TRACKING WITH PTC         ##########'
       print *, '###################################################'
       print *, '###################################################'
    endif
    
    if (rplot) then
      call newrplot()
    endif  


    if(.not.associated(my_ring%t))  then
      CALL MAKE_node_LAYOUT(my_ring)
    endif
    
    n=1
    npart = getnumberoftracks()
    if (getdebug() > 0) print *, 'There is ', npart,' tracks'
    
!     IF(.NOT.ASSOCIATED(TheBeam%N)) THEN
        CALL ALLOCATE_BEAM(TheBeam,npart)
!     ELSEIF(TheBeam%N/=npart) THEN
!        CALL KILL_BEAM(TheBeam)
!        CALL ALLOCATE_BEAM(TheBeam,npart)
!     ENDIF

    !!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!   
    !!!!!!!!!    READS DATA FROM MADX         !!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!   
    !!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!   

    do n=1, npart

       pathlegth = zero

       !if (getdebug() > 3 ) 
       print *, 'Getting track ',n

       call gettrack(n,TheBeam%X(n,1),TheBeam%X(n,2),TheBeam%X(n,3),TheBeam%X(n,4),TheBeam%X(n,6),TheBeam%X(n,5))

       !if (getdebug() > 0 ) 
       write(6,'(a10,1x,i8,1x,6(f9.6,1x))') 'Track ',n,TheBeam%X(n,1:6)
       
       TheBeam%X(n,7)=ZERO
       
       if( associated(TheBeam%POS(n)%NODE) ) then
             TheBeam%POS(n)%NODE=>my_ring%start%t1
       endif

    enddo !loop over tracks
       
    !!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!   
    !!!!!!!!!      TRACKING       !!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!   
    !!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!   
    
    open(unit=41,file='thintracking_ptc.txt')

    do t=1, nturns
       print*, "TURN NUMBER ",t
       p=>my_ring%start

       PREV_SLICE => my_ring%start%T1
       CURR_SLICE => prev_slice%next
       e = 1
       do ni=1, my_ring%last%T2%pos

          if ( .not. associated(CURR_SLICE%PARENT_FIBRE, PREV_SLICE%PARENT_FIBRE) ) then
            e = e + 1 
            p=>p%next
          endif


          call track(my_ring,TheBeam,getintstate(), pos1=ni, pos2=ni+1)
          pathlegth = curr_slice%s(3)

          if (getdebug() > 2 ) then
             write(6,*) e, 'l=',pathlegth
          endif

          do n=1, npart
             
             x = TheBeam%X(n,1:6)
             
             p0=(1+x(5))
             pz=sqrt(p0**2 - x(2)**2 - x(4)**2)
             p0 = p0*p%mag%p%p0c
             xp = x(2)/pz
             yp = x(4)/pz


!             write(41,'(i8, 1x, a16, i4 ,1x, 2f8.4, 1x, 6f8.4)') ni, p%mag%name, e,&
!                    pathlegth, TheBeam%X(n,7), &
!	x(1), xp , x(3), yp , x(5), p0 , x(6)

             write(41,'(i8,1x, a16, 1x, 3i4, 1x,2f8.4, 1x, 7f12.8)' ) ni, p%mag%name, e, n, t, &
                        pathlegth, TheBeam%X(n,7), &  
                        x(1), xp , x(3), yp , x(5), p0 , x(6)
             
             
             if (rplot) then
               gcs = my_false
               if (gcs) then
   !                write(6,'(a12,3f8.4)') "Magnet B ", p%mag%p%f%b(1), p%mag%p%f%b(2), p%mag%p%f%b(3)
                  gposx = x(1)*p%chart%f%exi(1,1) + x(3)*p%chart%f%exi(1,2) + x(6)*p%chart%f%exi(1,3)
                  gposy = x(1)*p%chart%f%exi(2,1) + x(3)*p%chart%f%exi(2,2) + x(6)*p%chart%f%exi(2,3)
                  gposz = x(1)*p%chart%f%exi(3,1) + x(3)*p%chart%f%exi(3,2) + x(6)*p%chart%f%exi(3,3)
   !                write(6,'(a12,3f8.4)') " Rotated ", gposx,gposy,gposz
                  gposx = gposx + p%chart%f%b(1)
                  gposy = gposy + p%chart%f%b(2)
                  gposz = gposz + p%chart%f%b(3)

                  write(6,'(a12, 2i6,3f8.4)') p%mag%name, n,e, gposx,gposy,gposz

                  call plottrack(n, e, t, gposx, xp , gposy, yp , x(5), p0 , gposz)
               else
                  call plottrack(n, e, t, x(1), xp , x(3), yp , x(5), p0 , x(6))
               endif
             endif             

             if ( observedelements(e) .gt. 0 ) then
               if ( associated(CURR_SLICE, p%t2 ) ) then
                 print*, "Sending to table", n, e, pathlegth
                 call putintracktable(n,t,observedelements(e),x(1), xp , x(3), yp , x(6), x(5), pathlegth, p0)
               endif 
             endif
             !fields in the table         "number", "turn", "x", "px", "y", "py", "t", "pt", "s", "e"
          
          enddo
          
!               call produce_aperture_flag(apertflag)
!               if (apertflag/=0) then
!                  print *, 'Particle out of aperture!'
! 
!                  call ANALYSE_APERTURE_FLAG(apertflag,why)
!                  Write(6,*) "ptc_trackline: APERTURE error for element: ",e," name: ",p%MAG%name
!                  Write(6,*) "Message: ",c_%message
!                  write(whymsg,*) 'APERTURE error: ',why
!                  call fort_warn('ptc_twiss: ',whymsg)
!                  call seterrorflag(10,"ptc_twiss: ",whymsg);
! 
!                  exit; !goes to the ne
!               endif

         if (associated(CURR_SLICE%next)) then
           PREV_SLICE => CURR_SLICE
           CURR_SLICE => CURR_SLICE%next
         else
           exit;
         endif  

       enddo !over elements

    enddo !loop over turns
    
    close(41)
    
    if (rplot) call rplotfinish()   
    call deletetrackstrarpositions()
    
    c_%x_prime=.false.

    CALL KILL_BEAM(TheBeam)

    deallocate (observedelements)
    !==============================================================================
  end subroutine ptc_track_everystep


  subroutine putintracktable (npart,turn,nobs,x,px,y,py,t,pt,spos,e)
    implicit none
    !--- purpose: enter particle coordinates in table                      *
    !    input:                                                            *
    !    npart  (int)           particle number                            *
    !    turn   (int)           turn number                                *
    !    nobs   (int)           observation point number                   *
    !----------------------------------------------------------------------*

    !vvk
    !      real(dp) :: tmp_coord_array(lnv), tmp_norm_array(lnv), tmp_norm
    integer  :: npart,turn,nobs
    real(kind(1d0)) :: tt
    character*36 table_puttab
    !hbu
    real(dp) :: x,px,y,py,t,pt
    real(kind(1d0)) :: spos,e
    !hbu
    data table_puttab / 'track.obs$$$$.p$$$$' /


    tt = turn
    write(table_puttab(10:13), '(i4.4)') nobs
    write(table_puttab(16:19), '(i4.4)') npart

    call double_to_table(table_puttab, 'turn ', tt)
    doublenum = x
    call double_to_table(table_puttab, 'x ' , doublenum)

    doublenum = px
    call double_to_table(table_puttab, 'px ', doublenum)

    doublenum = y
    call double_to_table(table_puttab, 'y ' , doublenum)

    doublenum = py
    call double_to_table(table_puttab, 'py ', doublenum)

    doublenum = t
    call double_to_table(table_puttab, 't ' , doublenum)

    doublenum = pt
    call double_to_table(table_puttab, 'pt ', doublenum)

    call double_to_table(table_puttab, 's ' , spos)
    call double_to_table(table_puttab, 'e ' , e)
    call augment_count(table_puttab)

  end subroutine putintracktable

  !_________________________________________________________________________________


  subroutine ptc_trackline(nobs)
    ! subroutine that performs tracking with acceleration
    ! it is called as a result of ptc_trackline MAD-X command

    implicit none
    integer, intent (IN) :: nobs ! the maximum number of observation points >=1
    INTEGER, ALLOCATABLE :: observedelements(:)
    integer  :: charge    ! charge of an accelerated particle
    type(fibre), pointer :: p
    real (dp)            :: x(1:6)
    !    real (dp)            :: polarx(1:6)   ! track vector -
    real (dp)            :: xp, yp, pz, p0
    real (dp)            :: pathlegth = zero
    integer              :: npart = 1
    integer              :: n = 1
    integer              :: nturns = 1
    integer              :: t = 1
    logical(lp)          :: gcs
    logical(lp)          :: rplot
    real (dp)            :: gposx, gposy, gposz
    integer              :: e
    integer              :: apertflag
    character(200)       :: whymsg
    integer              :: why(9)
    !    integer              :: rplotno
    integer              :: obspointnumber ! observation point number in c-code
    integer              :: getnumberoftracks !function
    type(internal_state)  :: intstate
    real(kind(1d0))      :: get_value,get_variable
    integer, external    :: get_option, &   !  int get_option(char*);
         restart_sequ, & !  restart beamline and return number of beamline node
         advance_node    !  advance to the next node in expanded sequence
    !                    !  =0 (end of range), =1 (else)
    REAL(KIND(1d0)), external :: node_value  !/*returns value for parameter par of current element */
    !------------------------------------------------------
    !initialization
    npart = 1
    n = 1
    t = 1
    !------------------------------------------------------

    if(universe.le.0) then
       call fort_warn('return from ptc_trackline: ',' no universe created')
       return
    endif
    if(index.le.0) then
       call fort_warn('return from ptc_trackline: ',' no layout created')
       return
    endif

    nturns = get_value('ptc_trackline ','turns ')
    if (getdebug() > 2) print *, 'ptc_trackline, nturns = ', nturns

    if ( (nturns > 1) .and. (my_ring%closed .eqv. .false.)) then
       call fort_warn('WARNING: You can not make more than one turn in a line!', &
            'Putting number of turns to 1!')
       nturns = 1
    endif


    gcs = get_value('ptc_trackline ','gcs ') .ne. 0

    rplot = get_value('ptc_trackline ','rootntuple ') .ne. 0
    
    intstate = getintstate()
    if (gcs .and.  intstate%TOTALPATH) then
       call fort_warn("ptc_trackline","Having global coordinates and totalpath for z is sensless")
       gcs = .false.
    endif


    allocate(observedelements(1:my_ring%n)); observedelements(:)=0 ! zero means that this element is not an obs. point

    c_%x_prime=.true.

    e=restart_sequ()
    p=>my_ring%start
    do e=1, my_ring%n

       obspointnumber=node_value('obs_point ')
       IF (e.eq.1) obspointnumber=1 ! node_value gives 0 for 1st (?)

       if (obspointnumber .gt. 0) then
          if (getdebug() > 0) print *,"Element ",e," is an observation point no. ",obspointnumber
          observedelements(e) = obspointnumber
       endif

       obspointnumber=advance_node() ! c-code go to the next node -> the passed value is never used, just to shut up a compiler
       p=>p%next
    enddo


    charge = get_value('beam ', "charge ");
    if (getdebug() > 3 ) print *, 'Read charge:', charge,' layout has charge ', my_ring%charge

    if (cavsareset .eqv. .false.) then
       call setcavities(my_ring,maxaccel)
    endif

    if (getdebug() > 0) print *, 'reading tracks starting posiotions from table ....'

    call gettrack(1,x(1),x(2),x(3),x(4),x(6),x(5))

    if (getdebug() > 0) print *, 'reading.... Done'

    if (getdebug() > 0) then
       print *, '###################################################'
       print *, '###################################################'
       print *, '######         TRACKING WITH PTC         ##########'
       print *, '###################################################'
       print *, '###################################################'
    endif
    
    if (rplot) then
      call newrplot()
    endif  

    n=1
    npart = getnumberoftracks()
    if (getdebug() > 0) print *, 'There is ', npart,' tracks'
    do n=1, npart

       pathlegth = zero

       if (getdebug() > 3 ) print *, 'Getting track ',n

       call gettrack(n,x(1),x(2),x(3),x(4),x(6),x(5))

       if (getdebug() > 0 ) write(6,'(a10,1x,i8,1x,6(f9.6,1x))') 'Track ',n,x

       do t=1, nturns

          p=>my_ring%start

          do e=1, my_ring%n

             call track(my_ring,x,e,e+1,getintstate())
             pathlegth = pathlegth + p%mag%p%ld

             if (getdebug() > 2 ) then
                write(6,*) e, 'l=',pathlegth
                write(6,'(6f8.4)') x
             endif

             p0=(1+x(5))
             pz=sqrt(p0**2 - x(2)**2 - x(4)**2)
             p0 = p0*p%mag%p%p0c
             xp = x(2)/pz
             yp = x(4)/pz

             if (rplot) then
               if (gcs) then
  !                write(6,'(a12,3f8.4)') "Magnet B ", p%mag%p%f%b(1), p%mag%p%f%b(2), p%mag%p%f%b(3)
                  gposx = x(1)*p%chart%f%exi(1,1) + x(3)*p%chart%f%exi(1,2) + x(6)*p%chart%f%exi(1,3)
                  gposy = x(1)*p%chart%f%exi(2,1) + x(3)*p%chart%f%exi(2,2) + x(6)*p%chart%f%exi(2,3)
                  gposz = x(1)*p%chart%f%exi(3,1) + x(3)*p%chart%f%exi(3,2) + x(6)*p%chart%f%exi(3,3)
  !                write(6,'(a12,3f8.4)') " Rotated ", gposx,gposy,gposz
                  gposx = gposx + p%chart%f%b(1)
                  gposy = gposy + p%chart%f%b(2)
                  gposz = gposz + p%chart%f%b(3)

                  write(6,'(a12, 2i6,3f8.4)') p%mag%name, n,e, gposx,gposy,gposz

                  call plottrack(n, e, t, gposx, xp , gposy, yp , x(5), p0 , gposz)
               else
                  call plottrack(n, e, t, x(1), xp , x(3), yp , x(5), p0 , x(6))
               endif
             endif             
             
             if ( observedelements(e) .gt. 0) then
                call putintracktable(n,t,observedelements(e),x(1), xp , x(3), yp , x(6), x(5), pathlegth, p0)
             endif
             !fields in the table         "number", "turn", "x", "px", "y", "py", "t", "pt", "s", "e"

             call produce_aperture_flag(apertflag)
             if (apertflag/=0) then
                print *, 'Particle out of aperture!'

                call ANALYSE_APERTURE_FLAG(apertflag,why)
                Write(6,*) "ptc_trackline: APERTURE error for element: ",e," name: ",p%MAG%name
                Write(6,*) "Message: ",c_%message
                write(whymsg,*) 'APERTURE error: ',why
                call fort_warn('ptc_twiss: ',whymsg)
                call seterrorflag(10,"ptc_twiss: ",whymsg);
                
                exit; !goes to the ne
             endif
             p=>p%next
          enddo !over elements

          if (apertflag/=0) then
             exit; !goes to the next particle
          endif

       enddo !loop over turns
    enddo !loop over tracks

    if (rplot) call rplotfinish()   
    call deletetrackstrarpositions()

    c_%x_prime=.false.

    deallocate (observedelements)
    !==============================================================================
  end subroutine ptc_trackline




  !_________________________________________________________________________________




  subroutine ptc_twiss_linac(tab_name)
    !   use madx_ptc_module, only: real_8, damap, berz
    implicit                none
    integer              :: tab_name(*)
    include 'twissa.fi'
    integer              :: charge    ! charge of an accelerated particle
    real(dp)             :: x0(6),betd,beta(3),gamma(3),ave(6,6,3),x1(6),xt(6)
    type(real_8)         :: y_pol(6), y2(6)
    type(damap)          :: mapA, id
    type(fibre), pointer :: p
    integer              :: n,no,np, iflag, i,j,k
    integer, allocatable :: ePP(:),ee(:) ! exponents of a monomial for x_1^{2}*x_3^{4}, j is [0,2,0,4]
    logical(lp)          :: sixd
    type(taylor)         :: mom,r2,I1,dispt(4),avet(6,6,3)
    real(kind(1d0))      :: get_value,get_variable ! c functions
    real(dp)             :: s
    integer              :: get_option ! c function
    real (dp)            :: disp(4)
    type(pol_block)      :: pb !pol_block - it enables additional parameter dependences (variable) for polynomials
    integer              :: ioptfun !number of parameters tu put in table using vector_to_table c-func
    real(kind(1d0))      :: opt_fun(72) !array with parameters that is passed to vector_to_table c-func
    integer              :: ii !iterator
    type(work)           :: nfen, startfen      ! New Fibre ENergy
    real(dp)             :: p0n,p0i
    real(dp)             :: deltae

    nfen = 0
    startfen = 0
    s = zero

    print *, '###################################################'
    print *, '###################################################'
    print *, '######          TWISS WITH PTC           ##########'
    print *, '###################################################'
    print *, '###################################################'

    !    c_%x_prime=.true.

    if(universe.le.0) then
       call fort_warn('return from ptc_twiss: ',' no universe created')
       return
    endif
    if(index.le.0) then
       call fort_warn('return from ptc_twiss: ',' no layout created')
       return
    endif

    table_name = charconv(tab_name)
    print *, "Table name is ", table_name

    charge = get_value('beam ', "charge ");
    if (getdebug() > 3) print *, 'Read charge:', charge,' layout has charge ', my_ring%charge

    if (cavsareset .eqv. .false.) then
       call setcavities(my_ring,maxaccel)
    endif

    print *, "START NEW TWISS"

    ! here is knob
    if (.false.) then
       pb=0
       pb%name="QUAD_L1"
       pb%ibn(2)=1
       my_ring=pb
    endif

    print77=.true.

    no=3   ! to be read BYLO 3
    np=0  ! to be discussed later

    if(my_nd_for_averaging/=2) then
       call init(getintstate(),no,c_%np_pol,berz)
    else
       call init(getintstate()+nocavity0,no,c_%np_pol,berz)
    endif

    call alloc(dispt,4)
    call alloc(mom);call alloc(r2,i1);

    do i=1,6
       do j=1,6
          do k=1,3
             call alloc(avet(i,j,k))
          enddo
       enddo
    enddo

    allocate(dismom(c_%nd,0:no/2))
!!! call a routine which sets dismon in each plane according to user definition
    call make_ring(1,one)
    call make_ring(2,one)
    call make_ring(3,one)

    allocate(ePP(lnv));
    allocate(ee(c_%nd2));
    ! no filename
    call alloc(id);
    call alloc(mapa);
    call alloc(y_pol);
    call alloc(y2);

    call setinitialparameters(x0)
    call setinitialtwiss(mapa)  ! initializes damap according to the initial parameters

    open(unit=20,file='testing.txt')
    open(unit=44,file='betax.ptc')
    open(unit=22,file='maps.txt')


    write(20,*)  "#########################################"

    s     = zero
    ee    = 0
    xt(:) = zero
    x1(:) = zero
    id    = 1     ! making identity map
    y_pol=x0+mapa

    p=>my_ring%start
    startfen=p  !setting up start energy for record

    do i=1,my_ring%n


       iflag=track_flag(my_ring,y_pol,i,i+1,+getintstate())

       mapa=y_pol
       mapa=mapa.sub.1

       call print(mapa%v(1),20)

       iflag=track_flag(my_ring,x1,i,i+1,+getintstate())
       x0=y_pol


       if(iflag/=0) then
          write(6,*) "problems "
          stop 999
       endif
       s=s+p%mag%p%ld
       write(20,*) "_______________________________________________________"
       call lattice_function_1(y_pol,ave,ePP)
       write(20,'(i4, 1x,a, f10.6)') i,p%mag%name,s
       write(20,*) ""
       write(20,*) ave(1,1,1)


       !      call average_x_i_x_j(y_pol,mom,1,1) !Computes <x_1 x_1>
       !      write(20,*) "<x_1 x_1>";
       !      call print(mom,20)

       if (.false.) then


          !_________________

          call lattice_function_1(y_pol,ave,ePP)
          call lattice_function_2(y_pol,avet)


          write(20,*)  "BetaX: Avarage as Taylor serie: avet(1,1,1)";
          !      print *, ave(1,1,1)
          !      call print(avet(1,1,1),6)

          write(20,*) "";
          write(20,*) 'Average as scalar : betax=d<x_1**2>/dI_1  and betay=d<x_3**2>/dI_2'
          write(20,'(2(1x,f10.6))') ave(1,1,1),ave(3,3,2)
          write(6,'(2(1x,f10.6))') ave(1,1,1),ave(3,3,2)
          write(20,*) ave(1,1,1)
          write(20,*)  "__________________________________________"; write(20,*) "";

          !_________________
          call average_x_i_x_j(y_pol,mom,1,1) !Computes <x_1 x_1>
          write(20,*) "<x_1 x_1>";
          call print(mom,20)
          write(20,*)  "__________________________________________"; write(20,*) "";

          !_________________
          call average_x_i_x_j(y_pol,mom,1,0) !Computes <x_1 0>
          write(20,*) "<x_1>";
          call print(mom,20)
          write(20,*)  "__________________________________________"; write(20,*) "";

          !_________________
          call lattice_function_disp_1(y_pol,disp)!Computes <x_i x_j> assuming linearity and no parameters
          write(20,*) "disp(1): Computes <x_i x_j> assuming linearity and no parameters"
          write(20,*) disp(1)
          write(20,*)  "__________________________________________"; write(20,*) "";

          !_________________
          call lattice_function_disp_2(y_pol,dispt)!  Computes <x_i x_j> assuming linearity and with parameters
          write(20,*) "disp(1): Computes <x_i x_j> assuming linearity and with parameters"
          call print(dispt(1),20)
          write(20,*)  "#########################################"; write(20,*) "";

       endif

       if (.true.) then

          doublenum = s
          call double_to_table(table_name, 's ', doublenum)
          doublenum = p%mag%p%p0c
          call double_to_table(table_name, 'energy ', doublenum)


          do ii=1,c_%nd2 !
             opt_fun(ii)=y_pol(ii).sub.ee
             !          print *, "opt_fun(ii)",opt_fun(ii)
          enddo

          ioptfun=6
          call vector_to_table(table_name, 'x ', ioptfun, opt_fun(1))

          nfen=0

          if ( (associated(p%next) .eqv. .false. ) .or. (associated( p%next, my_ring%start)) ) then
             ! if p is the last element in the sequence i.e.
             ! p%next == NULL (LINE) OR
             ! p%next points the first element (CIRCLE)
             nfen=p
             !if it is the last element in the line
             print *, 'It is the last element  ', p%mag%name
             !(it is always marker, i.e element that does not change reference energy)
             print *, 'Its reference energy is ', nfen%p0c
             !take its reference energy
          else
             nfen=p%next      ! energy after passing this element
          endif


          deltae = nfen%p0c / startfen%p0c


          opt_fun(:)=0
          opt_fun(1)=ave(1,1,1) * deltae !beta11
          opt_fun(2)=ave(1,1,2) * deltae !beta12
          opt_fun(3)=ave(1,1,3) * deltae !beta13


          opt_fun(4)=ave(3,3,1) * deltae !beta21
          opt_fun(5)=ave(3,3,2) * deltae !beta22
          opt_fun(6)=ave(3,3,3) * deltae !beta23

          opt_fun(7)=ave(5,5,1) * deltae !beta31
          opt_fun(8)=ave(5,5,2) * deltae !beta32
          opt_fun(9)=ave(5,5,3) * deltae !beta33

          !alphas
          opt_fun(10) = ave(1,2,1) * deltae
          opt_fun(11) = ave(1,2,2) * deltae
          opt_fun(12) = ave(1,2,3) * deltae

          opt_fun(13) = ave(3,4,1) * deltae!???
          opt_fun(14) = ave(3,4,2) * deltae
          opt_fun(15) = ave(3,4,3) * deltae

          opt_fun(16) = ave(5,6,1) * deltae
          opt_fun(17) = ave(5,6,1) * deltae
          opt_fun(18) = ave(5,6,1) * deltae

          !gammas
          opt_fun(19) = ave(2,2,1) * deltae
          opt_fun(20) = ave(2,2,2) * deltae
          opt_fun(21) = ave(2,2,3) * deltae

          opt_fun(22) = ave(4,4,1) * deltae
          opt_fun(23) = ave(4,4,2) * deltae
          opt_fun(24) = ave(4,4,3) * deltae

          opt_fun(25) = ave(6,6,3) * deltae
          opt_fun(26) = ave(6,6,3) * deltae
          opt_fun(27) = ave(6,6,3) * deltae




          ioptfun=36 !number of parameters tu put in table
          call vector_to_table(table_name, 'beta11 ', ioptfun, opt_fun(1))
          call augment_count(table_name)

          p0i=startfen%p0c
          p0n=nfen%p0c
          p0n=p0i/p0n
          ave(1,1,1)=ave(1,1,1)/p0n
          ave(2,2,1)=ave(2,2,1)/p0n
          ave(1,2,1)=ave(1,2,1)/p0n

          write (6,'(a10,4(a,f7.3))') p%mag%name, " s= ",s, " BETAX ", opt_fun(1), " BETAY ", opt_fun(5),&
               " Ener ", nfen%energy," deltae ",deltae
          !                print *, ave(1,1,1),ave(2,2,1),ave(1,2,1)
          !                print *, opt_fun(1),opt_fun(19),opt_fun(10)
          !                print *, "zero ",one - opt_fun(1)*opt_fun(19) + opt_fun(10)**2


       endif

       p=>p%next
    enddo

    close(20);close(22)

    call kill(id);
    call kill(mapa);
    call kill(y_pol);

    call kill(mom);
    call kill(y2);

    deallocate(ePP,ee)
    deallocate(dismom)

    !    c_%x_prime=.false.

    !****************************************************************************************
    !*********  E N D   O F   PTC_TWISS_LINAC  ************************************************
    !****************************************************************************************
    !________________________________________________________________________________________

  contains  ! what follows are internal subroutines of ptc_twiss_linac
    !____________________________________________________________________________________________
    subroutine setinitialparameters(x0)
      implicit none
      real (dp)            :: x0(6)
      real (dp)            :: x
      real (dp)            :: px
      real (dp)            :: y
      real (dp)            :: py
      real (dp)            :: t
      real (dp)            :: pt

      x        = get_value('ptc_twiss_linac ','x ')
      print *,'x ',x
      px       = get_value('ptc_twiss_linac ','px ')
      print *,'px ',px

      y        = get_value('ptc_twiss_linac ','y ')
      print *,'y ',y
      py       = get_value('ptc_twiss_linac ','py ')
      print *,'py ',py

      t        = get_value('ptc_twiss_linac ','t ')
      print *,'t ',t
      pt       = get_value('ptc_twiss_linac ','pt ')
      print *,'pt ',pt



      x0(1)=x;
      x0(2)=px;
      x0(3)=y;
      x0(4)=py;
      x0(5)=pt;x0(6)=t;

    end subroutine setinitialparameters

    !____________________________________________________________________________________________
    subroutine setinitialtwiss(mapa)
      implicit none
      type (damap)         :: mapa
      real (dp)            :: betx
      real (dp)            :: alfx
      real (dp)            :: bety
      real (dp)            :: alfy
      real (dp)            :: gamdelta
      real (dp)            :: alfdelta
      real (dp)            :: ddx
      real (dp)            :: ddpx
      real (dp)            :: ddy
      real (dp)            :: ddpy

      betx     = get_value('ptc_twiss_linac ','betx ')
      print *,'betx ',betx
      alfx     = get_value('ptc_twiss_linac ','alfx ')
      print *,'alfx ',alfx

      bety     = get_value('ptc_twiss_linac ','bety ')
      print *,'bety ',bety
      alfy     = get_value('ptc_twiss_linac ','alfy ')
      print *,'alfy ',alfy

      gamdelta = get_value('ptc_twiss_linac ','gamdelta ')
      print *,'gamdelta ',gamdelta
      alfdelta = get_value('ptc_twiss_linac ','alfdelta ')
      print *,'alfdelta ',alfdelta

      ddx      = get_value('ptc_twiss_linac ','ddx ')
      print *,'ddx ',ddx
      ddpx     = get_value('ptc_twiss_linac ','ddpx ')
      print *,'ddpx ',ddpx
      ddy      = get_value('ptc_twiss_linac ','ddy ')
      print *,'ddy ',ddy
      ddpy     = get_value('ptc_twiss_linac ','ddpy ')
      print *,'ddpy ',ddpy


      if ( (betx .le. 0) .and. (bety .le. 0)  ) then
         print *, "User must provide initial conditions ..."
         stop;
      endif

      mapa=1 ! makes identity map
      mapa%v(1)=sqrt(betx)*(one.mono.1) + ddx*(one.mono.5)
      mapa%v(2)=(one/sqrt(betx))*(one.mono.2) - (alfx/sqrt(betx))*(one.mono.1)+ ddpx*(one.mono.5)
      mapa%v(3)=sqrt(bety)*(one.mono.3) + ddy*(one.mono.5)
      mapa%v(4)=(one/sqrt(bety))*(one.mono.4) - (alfy/sqrt(bety))*(one.mono.3)+ ddpy*(one.mono.5)

      if(c_%nd2 == 6) then
         if (gamdelta > 0) then
            print *,"We go 6D"
            betd=(one+alfdelta**2)/gamdelta
            mapa%v(5)=sqrt(betd)*(one.mono.5)
            mapa%v(6)=(one/sqrt(betd))*(one.mono.6) - (alfdelta/sqrt(betd))*(one.mono.5)
         else
            print *, "Error: User must provide initial conditions:"
            print *, "Error: 6D calculation requested but initial gamdelta is 0"
            stop;
         endif
      else
         print *,"We go 4D"
      endif



    end subroutine setinitialtwiss

  end subroutine ptc_twiss_linac
  !_________________________________________________________________________________

  subroutine make_gaussian(plane,I0)
    implicit none
    integer plane,i
    real(dp) I0

    dismom(plane,0)=one

    do i=1,c_%no/2
       dismom(plane,i)=i*I0*two*dismom(plane,i-1)
    enddo

  end   subroutine make_gaussian
  !_________________________________________________________________________________

  subroutine make_ring(plane,I0)
    implicit none
    integer plane,i
    real(dp) I0

    dismom(plane,0)=one

    do i=1,c_%no/2
       dismom(plane,i)=I0*two*dismom(plane,i-1)
    enddo

  end   subroutine make_ring
  !_________________________________________________________________________________

  subroutine lattice_function_1(y,ave,e)   !  Computes <x_i x_j> assuming linearity and no parameters
    implicit none
    type(real_8) y(6)
    real(dp) ave(6,6,3)
    integer e(:)
    integer i,j,k

    e=0
    ave=zero
    do i=1,c_%nd2
       do j=i,c_%nd2
          do k=1,c_%nd
             e(k*2-1)=1
             ave(i,j,k)=ave(i,j,k)+(y(i).sub.e)*(y(j).sub.e)
             e(k*2-1)=0
             e(k*2)=1
             ave(i,j,k)=ave(i,j,k)+(y(i).sub.e)*(y(j).sub.e)
             e(2*k)=0
             ave(j,i,k)=ave(i,j,k)
          enddo
       enddo
    enddo

  end subroutine lattice_function_1
  !_________________________________________________________________________________
  subroutine lattice_function_2(y,ave)   !  Computes <x_i x_j> assuming linearity and with parameters
    implicit none
    type(real_8) y(6)
    type(taylor) ave(6,6,3)
    integer i,j,k
    integer, allocatable :: e(:)

    allocate(e(c_%npara_fpp))

    e=0
    do i=1,c_%nd2
       do j=i,c_%nd2
          do k=1,c_%nd
             ave(i,j,k)=zero
             e(k*2-1)=1
             ave(i,j,k)= ave(i,j,k) + (y(i)%t.par.e)*(y(j)%t.par.e) !*
             e(k*2-1)=0
             e(k*2)=1
             ave(i,j,k)=morph(ave(i,j,k))+ (y(i).par.e)*(y(j).par.e) !line * does the same, here taylor is morphed to polimorph,
             e(2*k)=0                                                !and above taylor component of polimorph is used explicitely
             ave(j,i,k)=ave(i,j,k)
          enddo
       enddo
    enddo

    deallocate(e)
  end subroutine lattice_function_2
  !_________________________________________________________________________________

  subroutine lattice_function_disp_1(y,disp)   !  Computes <x_i x_j> assuming linearity and no parameters
    implicit none
    type(real_8) y(6)
    real(dp) disp(4)
    integer i
    integer, allocatable :: j(:)

    allocate(j(c_%nv))

    j=0
    j(5)=1

    do i=1,4
       disp(i)=y(i).sub.j
    enddo

    deallocate(j)
  end subroutine lattice_function_disp_1
  !_________________________________________________________________________________
  subroutine lattice_function_disp_2(y,disp)   !  Computes <x_i x_j> assuming linearity and with parameters
    implicit none
    type(real_8) y(6)
    type(taylor) disp(4)
    integer i
    integer, allocatable :: j(:)

    allocate(j(c_%npara_fpp))

    j=0
    j(5)=1

    do i=1,4
       disp(i)=y(i).par.j
    enddo

    deallocate(j)
  end subroutine lattice_function_disp_2
  !_________________________________________________________________________________

  subroutine average_x_i_x_j(y,ave,i,j)   !  Computes <x_i x_j>
    implicit none
    type(real_8) y(6)
    type(taylor) ave
    type(taylorresonance) tr
    integer i,j

    call alloc(tr)

    if(j/=0) then
       tr=y(i)%t*y(j)%t
    else
       tr=y(i)%t
    endif

    call cfu(tr%cos,filter,ave)

    call kill(tr)
  end subroutine average_x_i_x_j
  !_________________________________________________________________________________

  real(dp) function filter(e)   !  Computes <x_i x_j>
    implicit none
    integer e(:)
    integer i

    filter=one

    do i=1,my_nd_for_averaging
       if(e(2*i-1)/=e(2*i)) then
          filter=zero
          return
       else
          filter=filter*dismom(i,e(2*i))
       endif
    enddo

  end function filter
  !_________________________________________________________________________________



  subroutine knobs
    implicit none
    type (pol_block) :: pb1,pb2
    real (dp)        :: x(6)
    integer          :: id
    type (real_8)    :: y

    pb1=0
    pb1%name='qf' ! STICKING NAME OF FAMILY
    pb1%ibn(2)=1
    pb2=0
    pb2%name='qD' ! STICKING NAME OF FAMILY
    pb2%ibn(2)=2
    my_ring=pb1
    my_ring=pb2
    call kill_para(my_ring)
    pb1=0
    pb1%name='qF' ! STICKING NAME OF FAMILY
    pb1%N_name=1 ! STICKING NAME OF FAMILY DEFINED BY THE FIRST N_NAME LETTERS
    pb1%ibn(2)=1
    my_ring=pb1
    call kill_para(my_ring)
    pb1=0
    pb1%name='qf' ! STICKING NAME OF FAMILY
    pb1%ibn(2)=1
    pb1%iAn(2)=2
    CALL SCAN_FOR_POLYMORPHS(my_ring,PB1)
    call kill_para(my_ring)
    pb1=0
    pb1%name='qf' ! STICKING NAME OF FAMILY
    pb1%ibn(2)=1
    pb2=0
    pb2%name='qf' ! STICKING NAME OF FAMILY
    pb2%iAn(2)=2
    CALL SCAN_FOR_POLYMORPHS(my_ring,PB1)
    CALL SCAN_FOR_POLYMORPHS(my_ring,PB2)
    write(6,*) c_%np_pol

    !    X=zero; CALL FIND_ORBIT(my_ring,X,1,DEFAULT)  !@1 Orbite Close

    !     CALL INIT(DEFAULT,2,c_%np_pol,BERZ)   !

    !     CALL ALLOC(f); CALL ALLOC(Y);CALL ALLOC(NORMAL);call alloc(id);  !@1  VARIABLES CREEES


    !      id=1      !@1 DAMAP= IDENTITE
    !      Y=X +id    !@1 POLYMORPHES= ORBITE CLOSE + IDENTITE

    !    CALL TRACK(RESEAU,Y,1,+DEFAULT)

  end subroutine knobs


end module madx_ptc_trackline_module


!              if (getdebug() > 3) then
!                 write(6,*) p%mag%name
!                 write(6,'(a12,3f8.4)') "Chart  B ", p%chart%f%b(1), p%chart%f%b(2), p%chart%f%b(3)
!                 write(6,'(a12,3f8.4)') "Magnet B ", p%mag%p%f%b(1), p%mag%p%f%b(2), p%mag%p%f%b(3)
!                 write(6,'(a12,3f8.4)') "Chart Exi1 ", p%chart%f%exi(1,1), p%chart%f%exi(1,2), p%chart%f%exi(1,3)
!                 write(6,'(a12,3f8.4)') "Chart Exi2 ", p%chart%f%exi(2,1), p%chart%f%exi(2,2), p%chart%f%exi(2,3)
!                 write(6,'(a12,3f8.4)') "Chart Exi2 ", p%chart%f%exi(3,1), p%chart%f%exi(3,2), p%chart%f%exi(3,3)
!                 write(6,'(a12,3f8.4)') "mag Exi1 ", p%mag%p%f%exi(1,1), p%mag%p%f%exi(1,2), p%mag%p%f%exi(1,3)
!                 write(6,'(a12,3f8.4)') "mag Exi2 ", p%mag%p%f%exi(2,1), p%mag%p%f%exi(2,2), p%mag%p%f%exi(2,3)
!                 write(6,'(a12,3f8.4)') "mag Exi2 ", p%mag%p%f%exi(3,1), p%mag%p%f%exi(3,2), p%mag%p%f%exi(3,3)
!              endif
! 
