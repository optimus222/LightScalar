      SUBROUTINE PREPARE_GROUPING_CHOICE(PP, WGT, INIT)
C     ****************************************************
C     
C     Generated by MadGraph5_aMC@NLO v. 3.1.0, 2021-03-30
C     By the MadGraph5_aMC@NLO Development Team
C     Visit launchpad.net/madgraph5 and amcatnlo.web.cern.ch
C     
C     INPUT
C     PP : MOMENTA
C     INIT: FLAG to RESET CUMULATIVE VARIABLE
C     (set on True for event by event selection)
C     WGT: Jacobian used so far (no update here)
C     
C     OUTPUT:
C     SELPROC()
C     SUMPROB
C     ****************************************************      
      USE DISCRETESAMPLER
      IMPLICIT NONE



      INCLUDE 'genps.inc'
      INCLUDE 'maxconfigs.inc'
      INCLUDE 'nexternal.inc'
      INCLUDE 'maxamps.inc'

      INTEGER I,J, IPROC, IMIRROR
      DOUBLE PRECISION PP(*), WGT
      LOGICAL INIT


      DOUBLE PRECISION SELPROC(2, MAXSPROC, LMAXCONFIGS)
      INTEGER LARGEDIM
      PARAMETER (LARGEDIM=2*MAXSPROC*LMAXCONFIGS)
      DATA SELPROC/LARGEDIM*0D0/
      DOUBLE PRECISION SUMPROB
      DATA SUMPROB/0D0/
      COMMON /TO_GROUPING_SELECTION/SUMPROB,SELPROC

C     TODO: MOVE THIS AS A COMMON BLOCK?      
      INTEGER CONFSUB(MAXSPROC,LMAXCONFIGS)
      INCLUDE 'config_subproc_map.inc'
      INTEGER PERMS(NEXTERNAL,LMAXCONFIGS)
      INCLUDE 'symperms.inc'
      LOGICAL MIRRORPROCS(MAXSPROC)
      INCLUDE 'mirrorprocs.inc'

      INTEGER SYMCONF(0:LMAXCONFIGS)
      COMMON /TO_SYMCONF/ SYMCONF


      DOUBLE PRECISION XDUM, XSDUM, DUM

      INTEGER LMAPPED

      DOUBLE PRECISION DSIGPROC
      INCLUDE 'vector.inc'
      INCLUDE 'run.inc'
C     To limit the number of calls to switchmom, use in DSIGPROC the
C     cached variable last_iconfig. It is in this subroutine as well
C     so that we can set it to -1 to ignore caching (to prevent
C     undesired effect if this subroutine is called from elsewhere
C     and to 0 to reset the cache.
      INTEGER LAST_ICONF
      DATA LAST_ICONF/-1/
      COMMON/TO_LAST_ICONF/LAST_ICONF

      LOGICAL INIT_MODE
      COMMON /TO_DETERMINE_ZERO_HEL/INIT_MODE
C     CM_RAP has parton-parton system rapidity -> need to check if
C      track correctly
      DOUBLE PRECISION CM_RAP
      LOGICAL SET_CM_RAP
      COMMON/TO_CM_RAP/SET_CM_RAP,CM_RAP

C     Select among the subprocesses based on PDF weight
      IF(INIT)THEN
        SUMPROB=0D0
        SELPROC(:,:,:) = 0D0
      ENDIF
C     Turn caching on in dsigproc to avoid too many calls to switchmom
      LAST_ICONF=0
      DO J=1,SYMCONF(0)
        DO IPROC=1,MAXSPROC
          IF(INIT_MODE.OR.CONFSUB(IPROC,SYMCONF(J)).NE.0) THEN
            DO IMIRROR=1,2
              IF(IMIRROR.EQ.1.OR.MIRRORPROCS(IPROC))THEN
C               Calculate PDF weight for all subprocesses
                XSDUM =  DSIGPROC(PP,J,IPROC,IMIRROR,SYMCONF,CONFSUB
     $           ,DUM,4)
                SELPROC(IMIRROR,IPROC,J)= SELPROC(IMIRROR,IPROC,J) +
     $            XSDUM
                IF(MC_GROUPED_SUBPROC) THEN
                  CALL MAP_3_TO_1(J,IPROC,IMIRROR,MAXSPROC,2,LMAPPED)
                  CALL DS_ADD_ENTRY('PDF_convolution',LMAPPED
     $             , XSDUM,.TRUE.)
                ENDIF
                SUMPROB=SUMPROB+XSDUM
                IF(IMIRROR.EQ.2)THEN
C                 Need to flip back x values
                  XDUM=XBK(1)
                  XBK(1)=XBK(2)
                  XBK(2)=XDUM
                  CM_RAP=-CM_RAP
                ENDIF
              ENDIF
            ENDDO
          ENDIF
        ENDDO
      ENDDO
C     Turn caching in dsigproc back off to avoid side effects.
      LAST_ICONF=-1

C     Cannot make a selection with all PDFs to zero, so we return now
      IF(SUMPROB.EQ.0.0D0) THEN
        RETURN
      ENDIF
      END

      SUBROUTINE SELECT_GROUPING(IMIRROR, IPROC, ICONF, WGT, IWARP)
      USE DISCRETESAMPLER
      IMPLICIT NONE
C     
C     INPUT (VIA COMMAND BLOCK)
C     SELPROC 
C     SUMPROB
C     INPUT
C     VECSIZE_USED (number of weight to update)
C     INPUT/OUTPUT
C     WGT(VECSIZE_USED) #multiplied by the associated jacobian      
C     
C     OUTPUT
C     
C     iconf, iproc, imirror
C     
      INTEGER  IWARP
      INTEGER IVEC
      DOUBLE PRECISION WGT(*)
      INTEGER IMIRROR, IPROC, ICONF

C     
C     CONSTANTS
C     
      INCLUDE 'genps.inc'
      INCLUDE 'maxconfigs.inc'
      INCLUDE 'nexternal.inc'
      INCLUDE 'maxamps.inc'
C     
      DOUBLE PRECISION R
C     
      DOUBLE PRECISION SELPROC(2, MAXSPROC, LMAXCONFIGS)
      INTEGER LARGEDIM
      PARAMETER (LARGEDIM=2*MAXSPROC*LMAXCONFIGS)
      DOUBLE PRECISION SUMPROB
      COMMON /TO_GROUPING_SELECTION/SUMPROB,SELPROC

      INTEGER SYMCONF(0:LMAXCONFIGS)
      COMMON /TO_SYMCONF/ SYMCONF
C     
C     LOCAL
C     
      INTEGER I,J,K
      DOUBLE PRECISION TOTWGT
      INTEGER CONFSUB(MAXSPROC,LMAXCONFIGS)
      INCLUDE 'config_subproc_map.inc'

C     
C     VARIABLE FOR THE MC over proccess with importance sampling
C      additional factor
C     
      LOGICAL INIT_MODE
      COMMON/TO_DETERMINE_ZERO_HEL/INIT_MODE
      INTEGER GROUPED_MC_GRID_STATUS
      REAL*8 MC_GROUPED_PROC_JACOBIAN
      INTEGER LMAPPED
      INCLUDE 'vector.inc'
      INCLUDE 'run.inc'
C     Perform the selection
      CALL RANMAR(R)

C     It is important to cache the status before adding any entries to
C     this grid in this
C     routine since it might change it
      GROUPED_MC_GRID_STATUS = DS_GET_DIM_STATUS('grouped_processes')


C     If we are still initializing the grid or simply not using one at
C     all, then we pick a point based on PDF only.
      IF (.NOT.MC_GROUPED_SUBPROC.OR.GROUPED_MC_GRID_STATUS.EQ.0) THEN
        R=R*SUMPROB
        ICONF=0
        IPROC=0
        TOTWGT=0D0
        DO J=1,SYMCONF(0)
          DO I=1,MAXSPROC
            IF(INIT_MODE.OR.CONFSUB(I,SYMCONF(J)).NE.0) THEN
              DO K=1,2
                TOTWGT=TOTWGT+SELPROC(K,I,J)
                IF(R.LT.TOTWGT)THEN
                  IPROC=I
                  ICONF=J
                  IMIRROR=K
                  GOTO 50
                ENDIF
              ENDDO
            ENDIF
          ENDDO
        ENDDO
 50     CONTINUE
C       Update weigth w.r.t SELPROC normalized to selection probability

        DO I=1, WARP_SIZE
          IVEC = (IWARP -1) *WARP_SIZE + I
          WGT(IVEC)=WGT(IVEC)*(SUMPROB/SELPROC(IMIRROR,IPROC,ICONF))
        ENDDO

      ELSE
C       We are using the grouped_processes grid and it is initialized.
        CALL DS_GET_POINT('grouped_processes',R,LMAPPED
     $   ,MC_GROUPED_PROC_JACOBIAN,'norm',(/'PDF_convolution'/))
        DO I=1, WARP_SIZE
          IVEC = (IWARP -1) *WARP_SIZE + I
          WGT(IVEC)=WGT(IVEC)*MC_GROUPED_PROC_JACOBIAN
        ENDDO
        CALL MAP_1_TO_3(LMAPPED,MAXSPROC,2,ICONF,IPROC,IMIRROR)
      ENDIF
      RETURN
      END

      SUBROUTINE DSIG_VEC(ALL_P,ALL_WGT,ALL_XBK,ALL_Q2FACT,ALL_CM_RAP
     $ ,ICONF_VEC,IPROC,IMIRROR_VEC,ALL_OUT,VECSIZE_USED)
C     ******************************************************
C     
C     INPUT: ALL_PP(0:3, NEXTERNAL, VECSIZE_USED)
C     INPUT/OUtpUT       ALL_WGT(VECSIZE_USED)
C     VECSIZE_USED = vector size
C     ALL_OUT(VECSIZE_USED)
C     function (PDf*cross)
C     ******************************************************
      USE DISCRETESAMPLER
      IMPLICIT NONE

      INTEGER VECSIZE_USED
      INCLUDE 'vector.inc'
      INCLUDE 'genps.inc'
      DOUBLE PRECISION ALL_P(4*MAXDIM/3+14,*)
      DOUBLE PRECISION ALL_WGT(*)
      DOUBLE PRECISION ALL_XBK(2,*)
      DOUBLE PRECISION ALL_Q2FACT(2,*)
      DOUBLE PRECISION ALL_CM_RAP(*)
      INTEGER ICONF_VEC(NB_WARP), IPROC, IMIRROR_VEC(NB_WARP)
      DOUBLE PRECISION ALL_OUT(*)
      INCLUDE 'maxconfigs.inc'
      INCLUDE 'maxamps.inc'

      INTEGER LARGEDIM
      PARAMETER (LARGEDIM=2*MAXSPROC*LMAXCONFIGS)

      INTEGER CONFSUB(MAXSPROC,LMAXCONFIGS)
      INCLUDE 'config_subproc_map.inc'

C     SUBDIAG is vector of diagram numbers for this config
C     IB gives which beam is which (for mirror processes)
      INTEGER SUBDIAG(MAXSPROC),IB(2)
      COMMON/TO_SUB_DIAG/SUBDIAG,IB

      INTEGER MAPCONFIG(0:LMAXCONFIGS), ICONFIG
      COMMON/TO_MCONFIGS/MAPCONFIG, ICONFIG

      DOUBLE PRECISION SUMWGT(2, MAXSPROC,LMAXCONFIGS)
      INTEGER NUMEVTS(2, MAXSPROC,LMAXCONFIGS)
      COMMON /DSIG_SUMPROC/SUMWGT,NUMEVTS

      DOUBLE PRECISION DSIGPROC

      INTEGER SYMCONF(0:LMAXCONFIGS)
      COMMON /TO_SYMCONF/ SYMCONF

      INTEGER IMIRROR_GLOBAL, IPROC_GLOBAL
      COMMON/TO_MIRROR/ IMIRROR_GLOBAL, IPROC_GLOBAL

      DOUBLE PRECISION SELPROC(2, MAXSPROC, LMAXCONFIGS)
      DOUBLE PRECISION SUMPROB
      COMMON /TO_GROUPING_SELECTION/SUMPROB,SELPROC

      LOGICAL CUTSDONE,CUTSPASSED
      COMMON/TO_CUTSDONE/CUTSDONE,CUTSPASSED

      INTEGER I, CURR_WARP, NB_WARP_USED
      INTEGER GROUPED_MC_GRID_STATUS

      INTEGER                                      LPP(2)
      DOUBLE PRECISION    EBEAM(2), XBK(2),Q2FACT(2)
      COMMON/TO_COLLIDER/ EBEAM   , XBK   ,Q2FACT,   LPP

      DOUBLE PRECISION CM_RAP
      LOGICAL SET_CM_RAP
      COMMON/TO_CM_RAP/SET_CM_RAP,CM_RAP

C     To be able to control when the matrix<i> subroutine can add
C      entries to the grid for the MC over helicity configuration
      LOGICAL ALLOW_HELICITY_GRID_ENTRIES
      DATA ALLOW_HELICITY_GRID_ENTRIES/.TRUE./
      COMMON/TO_ALLOW_HELICITY_GRID_ENTRIES/ALLOW_HELICITY_GRID_ENTRIES


      GROUPED_MC_GRID_STATUS = DS_GET_DIM_STATUS('grouped_processes')
      IMIRROR_GLOBAL = IMIRROR_VEC(1)
      IPROC_GLOBAL = IPROC
C     ICONFIG=SYMCONF(ICONF_VEC(1))
C     DO I=1,MAXSPROC
C     SUBDIAG(I) = CONFSUB(I,SYMCONF(ICONF_VEC(1)))
C     ENDDO

C     set the running scale 
C     and update the couplings accordingly
      CALL UPDATE_SCALE_COUPLING_VEC(ALL_P, ALL_WGT, ALL_Q2FACT,
     $  VECSIZE_USED)

      IF(GROUPED_MC_GRID_STATUS.EQ.0) THEN
C       If we were in the initialization phase of the grid for MC over
C        grouped processes, we must instruct the matrix<i> subroutine
C        not to add again an entry in the grid for this PS point at
C        the call DSIGPROC just below.
        ALLOW_HELICITY_GRID_ENTRIES = .FALSE.
      ENDIF

      CALL DSIGPROC_VEC(ALL_P,ALL_XBK,ALL_Q2FACT,ALL_CM_RAP,ICONF_VEC
     $ ,IPROC,IMIRROR_VEC,SYMCONF,CONFSUB,ALL_WGT,0,ALL_OUT
     $ ,VECSIZE_USED)


      DO I =1,VECSIZE_USED
C       Reset ALLOW_HELICITY_GRID_ENTRIES
        ALLOW_HELICITY_GRID_ENTRIES = .TRUE.

C       Below is how one would go about adding each point to the
C        grouped_processes grid
C       However, keeping only the initialization grid is better'
C       //' because in that case all grouped ME's
C       were computed with the same kinematics. For this reason, the
C        code below remains commented.
C       IF(grouped_MC_grid_status.ge.1) then
C       call map_3_to_1(ICONF,IPROC,IMIRROR,MAXSPROC,2,Lmapped)
C       call DS_add_entry('grouped_processes',Lmapped,(ALL_OUT(i)/SELPR
C       OC(IMIRROR,IPROC,ICONF)))
C       ENDIF

      ENDDO

      NB_WARP_USED = VECSIZE_USED / WARP_SIZE
      IF( NB_WARP_USED * WARP_SIZE .NE. VECSIZE_USED ) THEN
        WRITE(*,*) 'ERROR: NB_WARP_USED * WARP_SIZE .NE. VECSIZE_USED',
     &    NB_WARP_USED, WARP_SIZE, VECSIZE_USED
        STOP
      ENDIF

      DO CURR_WARP=1, NB_WARP_USED
        DO I=(CURR_WARP-1)*WARP_SIZE+1,CURR_WARP*WARP_SIZE
          IF(ALL_OUT(I).GT.0D0)THEN
C           Update summed weight and number of events
            SUMWGT(IMIRROR_VEC(CURR_WARP),IPROC,ICONF_VEC(CURR_WARP))
     $       =SUMWGT(IMIRROR_VEC(CURR_WARP),IPROC,ICONF_VEC(CURR_WARP))
     $       +DABS(ALL_OUT(I)*ALL_WGT(I))
            NUMEVTS(IMIRROR_VEC(CURR_WARP),IPROC,ICONF_VEC(CURR_WARP))
     $       =NUMEVTS(IMIRROR_VEC(CURR_WARP),IPROC,ICONF_VEC(CURR_WARP)
     $       )+1
          ENDIF
        ENDDO
      ENDDO

      RETURN
      END

      DOUBLE PRECISION FUNCTION DSIG(PP,WGT,IMODE)
C     ****************************************************
C     
C     Generated by MadGraph5_aMC@NLO v. 3.6.2, 2025-03-19
C     By the MadGraph5_aMC@NLO Development Team
C     Visit launchpad.net/madgraph5 and amcatnlo.web.cern.ch
C     
C     Process: e+ e- > e+ e- WEIGHTED<=4 @1
C     
C     RETURNS DIFFERENTIAL CROSS SECTION 
C     FOR MULTIPLE PROCESSES IN PROCESS GROUP
C     Input:
C     pp    4 momentum of external particles
C     wgt   weight from Monte Carlo
C     imode 0 run, 1 init, 2 reweight,
C     3 finalize, 4 only PDFs
C     Output:
C     Amplitude squared and summed
C     ****************************************************
      USE DISCRETESAMPLER
      IMPLICIT NONE
C     
C     CONSTANTS
C     
      INCLUDE 'genps.inc'
      INCLUDE 'maxconfigs.inc'
      INCLUDE 'nexternal.inc'
      INCLUDE 'maxamps.inc'
      REAL*8     PI
      PARAMETER (PI=3.1415926D0)
C     
C     ARGUMENTS 
C     
      DOUBLE PRECISION PP(0:3,NEXTERNAL), WGT
      INTEGER IMODE
C     
C     LOCAL VARIABLES 
C     
      INTEGER LMAPPED
      INTEGER I,J,K,LUN,ICONF,IMIRROR,NPROC
      SAVE NPROC
      INTEGER SYMCONF(0:LMAXCONFIGS)
      COMMON /TO_SYMCONF/ SYMCONF
      DOUBLE PRECISION SUMPROB,TOTWGT,R,XDUM
      INTEGER CONFSUB(MAXSPROC,LMAXCONFIGS)
      INCLUDE 'config_subproc_map.inc'
      INTEGER PERMS(NEXTERNAL,LMAXCONFIGS)
      INCLUDE 'symperms.inc'
      LOGICAL MIRRORPROCS(MAXSPROC)
      INCLUDE 'mirrorprocs.inc'
C     SELPROC is vector of selection weights for the subprocesses
C     SUMWGT is vector of total weight for the subprocesses
C     NUMEVTS is vector of event calls for the subprocesses
      DOUBLE PRECISION SELPROC(2, MAXSPROC,LMAXCONFIGS)
      DOUBLE PRECISION SUMWGT(2, MAXSPROC,LMAXCONFIGS)
      INTEGER NUMEVTS(2, MAXSPROC,LMAXCONFIGS)
      INTEGER LARGEDIM
      PARAMETER (LARGEDIM=2*MAXSPROC*LMAXCONFIGS)
      DATA SELPROC/LARGEDIM*0D0/
      DATA SUMWGT/LARGEDIM*0D0/
      DATA NUMEVTS/LARGEDIM*0/
      SAVE SELPROC
      COMMON /DSIG_SUMPROC/SUMWGT,NUMEVTS
      REAL*8 MC_GROUPED_PROC_JACOBIAN
      INTEGER GROUPED_MC_GRID_STATUS
C     
C     EXTERNAL FUNCTIONS
C     
      INTEGER NEXTUNOPEN
      DOUBLE PRECISION DSIGPROC
      EXTERNAL NEXTUNOPEN,DSIGPROC
C     
C     GLOBAL VARIABLES
C     
C     Common blocks

      INCLUDE '../../Source/PDF/pdf.inc'
C     CHARACTER*7         PDLABEL,EPA_LABEL
C     INTEGER       LHAID
C     COMMON/TO_PDF/LHAID,PDLABEL,EPA_LABEL

      INTEGER NB_SPIN_STATE(2)
      DATA  NB_SPIN_STATE /2,2/
      COMMON /NB_HEL_STATE/ NB_SPIN_STATE

      INCLUDE 'vector.inc'  ! defines VECSIZE_MEMMAX
      INCLUDE 'coupl.inc'  ! needs VECSIZE_MEMMAX (defined in vector.inc)
      INCLUDE 'run.inc'
C     ICONFIG has this config number
      INTEGER MAPCONFIG(0:LMAXCONFIGS), ICONFIG
      COMMON/TO_MCONFIGS/MAPCONFIG, ICONFIG
C     IPROC has the present process number
      INTEGER IPROC
      COMMON/TO_MIRROR/IMIRROR, IPROC
C     CM_RAP has parton-parton system rapidity
      DOUBLE PRECISION CM_RAP
      LOGICAL SET_CM_RAP
      COMMON/TO_CM_RAP/SET_CM_RAP,CM_RAP
C     Keep track of whether cuts already calculated for this event
      LOGICAL CUTSDONE,CUTSPASSED
      COMMON/TO_CUTSDONE/CUTSDONE,CUTSPASSED
C     To be able to control when the matrix<i> subroutine can add
C      entries to the grid for the MC over helicity configuration
      LOGICAL ALLOW_HELICITY_GRID_ENTRIES
      DATA ALLOW_HELICITY_GRID_ENTRIES/.TRUE./
      COMMON/TO_ALLOW_HELICITY_GRID_ENTRIES/ALLOW_HELICITY_GRID_ENTRIES
C     To limit the number of calls to switchmom, use in DSIGPROC the
C      cached variable last_iconfig. It is in this subroutine as well
C      so that we can set it to -1 to ignore caching (to prevent
C      undesired effect if this subroutine is called from elsewhere
C      and to 0 to reset the cache.
      INTEGER LAST_ICONF
      DATA LAST_ICONF/-1/
      COMMON/TO_LAST_ICONF/LAST_ICONF

      DOUBLE PRECISION DUM
      LOGICAL INIT_MODE
      COMMON /TO_DETERMINE_ZERO_HEL/INIT_MODE
C     ----------
C     BEGIN CODE
C     ----------
      DSIG=0D0

C     Make sure cuts are evaluated for first subprocess
C     CUTSDONE=.FALSE.
C     CUTSPASSED=.FALSE.

      IF(PDLABEL.EQ.'dressed'.AND.DS_GET_DIM_STATUS('ee_mc').EQ.-1)THEN
        CALL DS_REGISTER_DIMENSION('ee_mc', 0)
C       ! set both mode 1: resonances, 2: no resonances to 50-50
        CALL DS_ADD_BIN('ee_mc', 1)
        CALL DS_ADD_BIN('ee_mc', 2)
        CALL DS_ADD_ENTRY('ee_mc', 1, 0.5D0, .TRUE.)
        CALL DS_ADD_ENTRY('ee_mc', 2, 0.5D0, .TRUE.)
        CALL DS_UPDATE_GRID('ee_mc')
      ENDIF



      IF(IMODE.EQ.1)THEN
C       Set up process information from file symfact
        LUN=NEXTUNOPEN()
        IPROC=1
        SYMCONF(IPROC)=ICONFIG
        OPEN(UNIT=LUN,FILE='../symfact.dat',STATUS='OLD',ERR=20)
        DO WHILE(.TRUE.)
          READ(LUN,*,ERR=10,END=10) XDUM, ICONF
          IF(ICONF.EQ.-MAPCONFIG(ICONFIG))THEN
            IPROC=IPROC+1
            SYMCONF(IPROC)=INT(XDUM)
          ENDIF
        ENDDO
 10     SYMCONF(0)=IPROC
        CLOSE(LUN)
        RETURN
 20     SYMCONF(0)=IPROC
        WRITE(*,*)'Error opening symfact.dat. No permutations used.'
        RETURN
      ELSE IF(IMODE.EQ.2)THEN
C       Output weights and number of events
        SUMPROB=0D0
        DO J=1,SYMCONF(0)
          DO I=1,MAXSPROC
            DO K=1,2
              SUMPROB=SUMPROB+SUMWGT(K,I,J)
            ENDDO
          ENDDO
        ENDDO
        WRITE(*,*)'Relative summed weights:'
        IF (SUMPROB.NE.0D0)THEN
          DO J=1,SYMCONF(0)
            WRITE(*,'(2E12.4)')((SUMWGT(K,I,J)/SUMPROB,K=1,2),I=1
     $       ,MAXSPROC)
          ENDDO
        ENDIF
        SUMPROB=0D0
        DO J=1,SYMCONF(0)
          DO I=1,MAXSPROC
            DO K=1,2
              SUMPROB=SUMPROB+NUMEVTS(K,I,J)
            ENDDO
          ENDDO
        ENDDO
        WRITE(*,*)'Relative number of events:'
        IF (SUMPROB.NE.0D0)THEN
          DO J=1,SYMCONF(0)
            WRITE(*,'(2E12.4)')((NUMEVTS(K,I,J)/SUMPROB,K=1,2),I=1
     $       ,MAXSPROC)
          ENDDO
        ENDIF
        WRITE(*,*)'Events:'
        DO J=1,SYMCONF(0)
          WRITE(*,'(2I12)')((NUMEVTS(K,I,J),K=1,2),I=1,MAXSPROC)
        ENDDO
C       Reset weights and number of events
        DO J=1,SYMCONF(0)
          DO I=1,MAXSPROC
            DO K=1,2
              NUMEVTS(K,I,J)=0
              SUMWGT(K,I,J)=0D0
            ENDDO
          ENDDO
        ENDDO
        RETURN
      ELSE IF(IMODE.EQ.3)THEN
C       No finalize needed
        RETURN
      ENDIF

C     IMODE.EQ.0, regular run mode
      IF(MC_GROUPED_SUBPROC.AND.DS_GET_DIM_STATUS('grouped_processes')
     $ .EQ.-1) THEN
        CALL DS_REGISTER_DIMENSION('grouped_processes', 0)
        CALL DS_SET_MIN_POINTS(10,'grouped_processes')
        DO J=1,SYMCONF(0)
          DO IPROC=1,MAXSPROC
            IF(INIT_MODE.OR.CONFSUB(IPROC,SYMCONF(J)).NE.0) THEN
              DO IMIRROR=1,2
                IF(IMIRROR.EQ.1.OR.MIRRORPROCS(IPROC))THEN
                  CALL MAP_3_TO_1(J,IPROC,IMIRROR,MAXSPROC,2,LMAPPED)
                  CALL DS_ADD_BIN('grouped_processes',LMAPPED)
                ENDIF
              ENDDO
            ENDIF
          ENDDO
        ENDDO
      ENDIF
      IF(MC_GROUPED_SUBPROC.AND.DS_DIM_INDEX(RUN_GRID,
     $  'PDF_convolution',.TRUE.).EQ.-1) THEN
        CALL DS_REGISTER_DIMENSION('PDF_convolution', 0,
     $    ALL_GRIDS=.FALSE.)
      ENDIF


C     Select among the subprocesses based on PDF weight
      SUMPROB=0D0
C     Turn caching on in dsigproc to avoid too many calls to switchmom
      LAST_ICONF=0
      DO J=1,SYMCONF(0)
        DO IPROC=1,MAXSPROC
          IF(INIT_MODE.OR.CONFSUB(IPROC,SYMCONF(J)).NE.0) THEN
            DO IMIRROR=1,2
              IF(IMIRROR.EQ.1.OR.MIRRORPROCS(IPROC))THEN
C               Calculate PDF weight for all subprocesses
                SELPROC(IMIRROR,IPROC,J)=DSIGPROC(PP,J,IPROC,IMIRROR
     $           ,SYMCONF,CONFSUB,DUM,4)
                IF(MC_GROUPED_SUBPROC) THEN
                  CALL MAP_3_TO_1(J,IPROC,IMIRROR,MAXSPROC,2,LMAPPED)
                  CALL DS_ADD_ENTRY('PDF_convolution',LMAPPED
     $             ,SELPROC(IMIRROR,IPROC,J),.TRUE.)
                ENDIF
                SUMPROB=SUMPROB+SELPROC(IMIRROR,IPROC,J)
                IF(IMIRROR.EQ.2)THEN
C                 Need to flip back x values
                  XDUM=XBK(1)
                  XBK(1)=XBK(2)
                  XBK(2)=XDUM
                  CM_RAP=-CM_RAP
                ENDIF
              ENDIF
            ENDDO
          ENDIF
        ENDDO
      ENDDO
C     Turn caching in dsigproc back off to avoid side effects.
      LAST_ICONF=-1

C     Cannot make a selection with all PDFs to zero, so we return now
      IF(SUMPROB.EQ.0.0D0) THEN
        RETURN
      ENDIF


C     Perform the selection
      CALL RANMAR(R)

C     It is important to cache the status before adding any entries to
C      this grid in this
C     routine since it might change it
      GROUPED_MC_GRID_STATUS = DS_GET_DIM_STATUS('grouped_processes')

      IF (MC_GROUPED_SUBPROC.AND.GROUPED_MC_GRID_STATUS.EQ.0) THEN
C       We must initialize the grid and probe all channels
        SUMPROB=0.0D0
C       Turn caching on in dsigproc to avoid too many calls to
C        switchmom
        LAST_ICONF=0
        DO J=1,SYMCONF(0)
          DO I=1,MAXSPROC
            IF(INIT_MODE.OR.CONFSUB(I,SYMCONF(J)).NE.0) THEN
              DO K=1,2
                IF(K.EQ.1.OR.MIRRORPROCS(I))THEN
                  IPROC=I
                  ICONF=J
                  IMIRROR=K
C                 The IMODE=5 computes the matrix_element only,
C                  without PDF convolution 
                  DSIG=DSIGPROC(PP,ICONF,IPROC,IMIRROR,SYMCONF,CONFSUB
     $             ,WGT,5)
                  CALL MAP_3_TO_1(J,I,K,MAXSPROC,2,LMAPPED)
                  IF (SELPROC(K,I,J).NE.0.0D0) THEN
                    CALL DS_ADD_ENTRY('grouped_processes',LMAPPED,DSIG)
                  ENDIF
                  IF(K.EQ.2)THEN
C                   Need to flip back x values
                    XDUM=XBK(1)
                    XBK(1)=XBK(2)
                    XBK(2)=XDUM
                    CM_RAP=-CM_RAP
                  ENDIF
                  IF(INIT_MODE) THEN
                    SELPROC(K,I,J) = 1D0
                  ELSE
                    SELPROC(K,I,J) = DABS(DSIG*SELPROC(K,I,J))
                  ENDIF
                  SUMPROB = SUMPROB + SELPROC(K,I,J)
                ENDIF
              ENDDO
            ENDIF
          ENDDO
        ENDDO
C       Turn caching in dsigproc back off to avoid side effects.
        LAST_ICONF=-1
C       If these additional entries were enough to initialize the
C        gird, then update it
C       To do this check we must *not* used the cached varianble
C        grouped_MC_grid_status
        IF(DS_GET_DIM_STATUS('grouped_processes').GE.1) THEN
          CALL DS_UPDATE_GRID('grouped_processes')
          CALL RESET_CUMULATIVE_VARIABLE()
        ENDIF
      ENDIF

C     If we are still initializing the grid or simply not using one at
C      all, then we pick a point based on PDF only.
      IF (.NOT.MC_GROUPED_SUBPROC.OR.GROUPED_MC_GRID_STATUS.EQ.0) THEN
        R=R*SUMPROB
        ICONF=0
        IPROC=0
        TOTWGT=0D0
        DO J=1,SYMCONF(0)
          DO I=1,MAXSPROC
            IF(INIT_MODE.OR.CONFSUB(I,SYMCONF(J)).NE.0) THEN
              DO K=1,2
                TOTWGT=TOTWGT+SELPROC(K,I,J)
                IF(R.LT.TOTWGT)THEN
                  IPROC=I
                  ICONF=J
                  IMIRROR=K
                  GOTO 50
                ENDIF
              ENDDO
            ENDIF
          ENDDO
        ENDDO
 50     CONTINUE

        IF(IPROC.EQ.0) RETURN


C       Update weigth w.r.t SELPROC normalized to selection probability

        WGT=WGT*(SUMPROB/SELPROC(IMIRROR,IPROC,ICONF))

      ELSE
C       We are using the grouped_processes grid and it is initialized.
        CALL DS_GET_POINT('grouped_processes',R,LMAPPED
     $   ,MC_GROUPED_PROC_JACOBIAN,'norm',(/'PDF_convolution'/))
        WGT=WGT*MC_GROUPED_PROC_JACOBIAN
        CALL MAP_1_TO_3(LMAPPED,MAXSPROC,2,ICONF,IPROC,IMIRROR)
      ENDIF

C     Redo clustering to ensure consistent with final IPROC
      CUTSDONE=.FALSE.

      IF(GROUPED_MC_GRID_STATUS.EQ.0) THEN
C       If we were in the initialization phase of the grid for MC over
C        grouped processes, we must instruct the matrix<i> subroutine
C        not to add again an entry in the grid for this PS point at
C        the call DSIGPROC just below.
        ALLOW_HELICITY_GRID_ENTRIES = .FALSE.
      ENDIF

C     Call DSIGPROC to calculate sigma for process
      DSIG=DSIGPROC(PP,ICONF,IPROC,IMIRROR,SYMCONF,CONFSUB,WGT,IMODE)
C     Reset ALLOW_HELICITY_GRID_ENTRIES
      ALLOW_HELICITY_GRID_ENTRIES = .TRUE.

C     Below is how one would go about adding each point to the
C      grouped_processes grid
C     However, keeping only the initialization grid is better because'
C     //' in that case all grouped ME's
C     were computed with the same kinematics. For this reason, the
C      code below remains commented.
C     IF(grouped_MC_grid_status.ge.1) then
C     call map_3_to_1(ICONF,IPROC,IMIRROR,MAXSPROC,2,Lmapped)
C     call DS_add_entry('grouped_processes',Lmapped,(DSIG/SELPROC(IMIRR
C     OR,IPROC,ICONF)))
C     ENDIF

      IF(DSIG.GT.0D0)THEN
C       Update summed weight and number of events
        SUMWGT(IMIRROR,IPROC,ICONF)=SUMWGT(IMIRROR,IPROC,ICONF)
     $   +DABS(DSIG*WGT)
        NUMEVTS(IMIRROR,IPROC,ICONF)=NUMEVTS(IMIRROR,IPROC,ICONF)+1
      ENDIF

      RETURN
      END

      FUNCTION DSIGPROC(PP,ICONF,IPROC,IMIRROR,SYMCONF,CONFSUB,WGT
     $ ,IMODE)
C     ****************************************************
C     RETURNS DIFFERENTIAL CROSS SECTION 
C     FOR A PROCESS
C     Input:
C     pp    4 momentum of external particles
C     wgt   weight from Monte Carlo
C     imode 0 run, 1 init, 2 reweight, 3 finalize
C     Output:
C     Amplitude squared and summed
C     ****************************************************

      IMPLICIT NONE

      INCLUDE 'genps.inc'
      INCLUDE 'maxconfigs.inc'
      INCLUDE 'nexternal.inc'
      INCLUDE 'maxamps.inc'
      INCLUDE 'vector.inc'  ! defines VECSIZE_MEMMAX
      INCLUDE 'coupl.inc'  ! needs VECSIZE_MEMMAX (defined in vector.inc)
      INCLUDE 'run.inc'
C     
C     ARGUMENTS 
C     
      DOUBLE PRECISION DSIGPROC
      DOUBLE PRECISION PP(0:3,NEXTERNAL), WGT
      INTEGER ICONF,IPROC,IMIRROR,IMODE
      INTEGER SYMCONF(0:LMAXCONFIGS)
      INTEGER CONFSUB(MAXSPROC,LMAXCONFIGS)
C     
C     GLOBAL VARIABLES
C     
C     SUBDIAG is vector of diagram numbers for this config
C     IB gives which beam is which (for mirror processes)
      INTEGER SUBDIAG(MAXSPROC),IB(2)
      COMMON/TO_SUB_DIAG/SUBDIAG,IB
C     ICONFIG has this config number
      INTEGER MAPCONFIG(0:LMAXCONFIGS), ICONFIG
      COMMON/TO_MCONFIGS/MAPCONFIG, ICONFIG
C     CM_RAP has parton-parton system rapidity
      DOUBLE PRECISION CM_RAP
      LOGICAL SET_CM_RAP
      COMMON/TO_CM_RAP/SET_CM_RAP,CM_RAP
C     To limit the number of calls to switchmom, use in DSIGPROC the
C      cached variable last_iconfig. When set to -1, it ignores
C      caching (to prevent undesired effect if this subroutine is
C      called from elsewhere) and when set to 0, it resets the cache.
      INTEGER LAST_ICONF
      DATA LAST_ICONF/-1/
      COMMON/TO_LAST_ICONF/LAST_ICONF
C     
C     EXTERNAL FUNCTIONS
C     
      DOUBLE PRECISION DSIG1
      LOGICAL PASSCUTS
C     
C     LOCAL VARIABLES 
C     
      DOUBLE PRECISION P1(0:3,NEXTERNAL),XDUM
      INTEGER I,J,K,JC(NEXTERNAL)
      INTEGER PERMS(NEXTERNAL,LMAXCONFIGS)
      INCLUDE 'symperms.inc'
      SAVE P1,JC

      IF (LAST_ICONF.EQ.-1.OR.LAST_ICONF.NE.ICONF) THEN

        ICONFIG=SYMCONF(ICONF)
        DO I=1,MAXSPROC
          SUBDIAG(I) = CONFSUB(I,SYMCONF(ICONF))
        ENDDO

C       Set momenta according to this permutation
        CALL SWITCHMOM(PP,P1,PERMS(1,MAPCONFIG(ICONFIG)),JC,NEXTERNAL)

        IF (LAST_ICONF.NE.-1) THEN
          LAST_ICONF = ICONF
        ENDIF
      ENDIF

      IB(1)=1
      IB(2)=2

      IF(IMIRROR.EQ.2)THEN
C       Flip momenta (rotate around x axis)
        DO I=1,NEXTERNAL
          P1(2,I)=-P1(2,I)
          P1(3,I)=-P1(3,I)
        ENDDO
C       Flip beam identity
        IB(1)=2
        IB(2)=1
C       Flip x values (to get boost right)
        XDUM=XBK(1)
        XBK(1)=XBK(2)
        XBK(2)=XDUM
C       Flip CM_RAP (to get rapidity right)
        CM_RAP=-CM_RAP
      ENDIF

      DSIGPROC=0D0

C     not needed anymore ... can be removed ... set for debugging only
C        
C     IF (.not.PASSCUTS(P1)) THEN
C     stop 1
C     endif

C     set the running scale 
C     and update the couplings accordingly
      IF (VECSIZE_MEMMAX.LE.1) THEN  ! no-vector (NB not VECSIZE_USED!)
        CALL UPDATE_SCALE_COUPLING(PP, WGT)
      ENDIF




      IF (IMODE.EQ.0D0.AND.NB_PASS_CUTS.LT.2**12)THEN
        NB_PASS_CUTS = NB_PASS_CUTS + 1
      ENDIF
      IF(IPROC.EQ.1) DSIGPROC=DSIG1(P1,WGT,IMODE)  ! e+ e- > e+ e-
C     ENDIF

      IF (LAST_ICONF.NE.-1.AND.IMIRROR.EQ.2) THEN
C       Flip back local momenta P1 if cached
        DO I=1,NEXTERNAL
          P1(2,I)=-P1(2,I)
          P1(3,I)=-P1(3,I)
        ENDDO
      ENDIF

      RETURN

      END

C     ccccccccccccccccccccccccc      
C     vectorize version
C     ccccccccccccccccccccccccc

      SUBROUTINE DSIGPROC_VEC(ALL_P,ALL_XBK,ALL_Q2FACT,ALL_CM_RAP
     $ ,ICONF_VEC,IPROC,IMIRROR_VEC,SYMCONF,CONFSUB,ALL_WGT,IMODE
     $ ,ALL_OUT,VECSIZE_USED)
C     ****************************************************
C     RETURNS DIFFERENTIAL CROSS SECTION 
C     FOR A PROCESS
C     Input:
C     pp    4 momentum of external particles
C     wgt   weight from Monte Carlo
C     imode 0 run, 1 init, 2 reweight, 3 finalize
C     Output:
C     Amplitude squared and summed
C     ****************************************************

      IMPLICIT NONE

      INCLUDE 'genps.inc'
      INCLUDE 'maxconfigs.inc'
      INCLUDE 'nexternal.inc'
      INCLUDE 'maxamps.inc'
      INCLUDE 'vector.inc'  ! defines VECSIZE_MEMMAX/WARP_SIZE
      INCLUDE 'coupl.inc'  ! needs VECSIZE_MEMMAX (defined in vector.inc)
      INCLUDE 'run.inc'
C     
C     ARGUMENTS 
C     
      DOUBLE PRECISION ALL_P(4*MAXDIM/3+14,VECSIZE_MEMMAX)
      DOUBLE PRECISION ALL_XBK(2, VECSIZE_MEMMAX)
      DOUBLE PRECISION ALL_Q2FACT(2, VECSIZE_MEMMAX)
      DOUBLE PRECISION ALL_CM_RAP(VECSIZE_MEMMAX)
      DOUBLE PRECISION ALL_WGT(VECSIZE_MEMMAX)
      DOUBLE PRECISION ALL_OUT(VECSIZE_MEMMAX)
      DOUBLE PRECISION DSIGPROC
      INTEGER ICONF,IPROC,IMIRROR,IMODE
      INTEGER ICONF_VEC(NB_WARP), IMIRROR_VEC(NB_WARP)
      INTEGER CURR_WARP, IWARP, NB_WARP_USED
      INTEGER SYMCONF(0:LMAXCONFIGS)
      INTEGER CONFSUB(MAXSPROC,LMAXCONFIGS)
      INTEGER VECSIZE_USED
C     
C     GLOBAL VARIABLES
C     
C     SUBDIAG is vector of diagram numbers for this config
C     IB gives which beam is which (for mirror processes)
      INTEGER SUBDIAG(MAXSPROC),IB(2)
      COMMON/TO_SUB_DIAG/SUBDIAG,IB
C     ICONFIG has this config number
      INTEGER MAPCONFIG(0:LMAXCONFIGS), ICONFIG
      COMMON/TO_MCONFIGS/MAPCONFIG, ICONFIG
C     CM_RAP has parton-parton system rapidity
      DOUBLE PRECISION CM_RAP
      LOGICAL SET_CM_RAP
      COMMON/TO_CM_RAP/SET_CM_RAP,CM_RAP
C     To limit the number of calls to switchmom, use in DSIGPROC the
C      cached variable last_iconfig. When set to -1, it ignores
C      caching (to prevent undesired effect if this subroutine is
C      called from elsewhere) and when set to 0, it resets the cache.
      INTEGER LAST_ICONF
      DATA LAST_ICONF/-1/
      COMMON/TO_LAST_ICONF/LAST_ICONF
      INTEGER IVEC
C     
C     EXTERNAL FUNCTIONS
C     
      DOUBLE PRECISION DSIG1
      LOGICAL PASSCUTS
C     
C     LOCAL VARIABLES 
C     
      DOUBLE PRECISION ALL_P1(0:3,NEXTERNAL,VECSIZE_MEMMAX),XDUM
      INTEGER I,J,K,JC(NEXTERNAL)
      INTEGER PERMS(NEXTERNAL,LMAXCONFIGS)
      INCLUDE 'symperms.inc'
      SAVE ALL_P1,JC

      IF(LAST_ICONF.NE.-1) THEN
        STOP 25
      ENDIF
      LAST_ICONF = 0
      IWARP = 0  ! position within the current warp
      CURR_WARP = 1  ! current_warp used
      DO IVEC=1, VECSIZE_USED
        IWARP = IWARP + 1
        IF (IWARP.EQ.1) THEN
          IF (LAST_ICONF.EQ.-1.OR.LAST_ICONF.NE.ICONF_VEC(CURR_WARP))
     $      THEN
            ICONFIG=SYMCONF(ICONF_VEC(CURR_WARP))
            DO I=1,MAXSPROC
              SUBDIAG(I) = CONFSUB(I,SYMCONF(ICONF_VEC(CURR_WARP)))
            ENDDO
          ENDIF
C         ICONF = ICONF_VEC(CURR_WARP)
C         IMIRROR = IMIRROR_VEC(CURR_WARP)
        ENDIF
C       Set momenta according to this permutation
        CALL SWITCHMOM(ALL_P(1,IVEC),ALL_P1(0,1,IVEC),PERMS(1
     $   ,MAPCONFIG(ICONFIG)),JC,NEXTERNAL)
        LAST_ICONF = ICONF_VEC(CURR_WARP)
        IF (IWARP.EQ.WARP_SIZE) THEN
          CURR_WARP = CURR_WARP + 1
          IWARP = 0
        ENDIF
      ENDDO
      LAST_ICONF=-1

      NB_WARP_USED = VECSIZE_USED / WARP_SIZE
      IF( NB_WARP_USED * WARP_SIZE .NE. VECSIZE_USED ) THEN
        WRITE(*,*) 'ERROR: NB_WARP_USED * WARP_SIZE .NE. VECSIZE_USED',
     &    NB_WARP_USED, WARP_SIZE, VECSIZE_USED
        STOP
      ENDIF

      DO CURR_WARP=1,NB_WARP_USED
        IB(1)=0  ! This is set in auto_dsigX. set it to zero to create segfault if used at wrong time
        IB(2)=0  ! Same
        IMIRROR = IMIRROR_VEC(CURR_WARP)
        IF(IMIRROR.EQ.2)THEN
C         Flip momenta (rotate around x axis)
          DO IVEC = (CURR_WARP-1)*WARP_SIZE+1,CURR_WARP*WARP_SIZE
            DO I=1,NEXTERNAL
              ALL_P1(2,I, IVEC)=-ALL_P1(2,I,IVEC)
              ALL_P1(3,I, IVEC)=-ALL_P1(3,I,IVEC)
            ENDDO
            XDUM=ALL_XBK(1, IVEC)
            ALL_XBK(1, IVEC) = ALL_XBK(2, IVEC)
            ALL_XBK(2, IVEC) = XDUM
            ALL_CM_RAP(IVEC) = - ALL_CM_RAP(IVEC)
            IB(1) = 0
            IB(2) = 0
C           Flip beam identity -> moved to auto_dsigX (since depend of
C            the warp)
          ENDDO

        ENDIF
      ENDDO


      ALL_OUT(:)=0D0

      DO IVEC=1,VECSIZE_USED
        IF (IMODE.EQ.0D0.AND.NB_PASS_CUTS.LT.2**12.AND.ALL_WGT(IVEC)
     $   .NE.0D0)THEN
          NB_PASS_CUTS = NB_PASS_CUTS + 1
        ENDIF
      ENDDO

      IF(IPROC.EQ.1) CALL DSIG1_VEC(ALL_P1,ALL_XBK,ALL_Q2FACT
     $ ,ALL_CM_RAP,ALL_WGT,IMODE,ALL_OUT,SYMCONF, CONFSUB,ICONF_VEC
     $ ,IMIRROR_VEC,VECSIZE_USED)  ! e+ e- > e+ e-

C     FLIPPING BACK IF NEEDED
      DO CURR_WARP=1,NB_WARP_USED
        IF (IMIRROR_VEC(CURR_WARP).EQ.2) THEN
          DO IVEC = (CURR_WARP-1)*WARP_SIZE+1,CURR_WARP*WARP_SIZE
            DO I=1,NEXTERNAL
              ALL_P1(2,I,IVEC)=-ALL_P1(2,I,IVEC)
              ALL_P1(3,I,IVEC)=-ALL_P1(3,I,IVEC)
            ENDDO
          ENDDO
        ENDIF
      ENDDO

      RETURN

      END


C     -----------------------------------------
C     Subroutine to map three positive integers
C     I, J and K with upper bounds J_bound and
C     K_bound to a one_dimensional
C     index L
C     -----------------------------------------

      SUBROUTINE MAP_3_TO_1(I,J,K,J_BOUND,K_BOUND,L)
      IMPLICIT NONE
      INTEGER, INTENT(IN)  :: I,J,K,J_BOUND,K_BOUND
      INTEGER, INTENT(OUT) :: L

      L = I*(J_BOUND*(K_BOUND+1)+K_BOUND+1)+J*(K_BOUND+1)+K

      END SUBROUTINE MAP_3_TO_1

C     -----------------------------------------
C     Subroutine to map back the positive 
C     integer L to the three integers 
C     I, J and K with upper bounds
C     J_bound and K_bound.
C     -----------------------------------------

      SUBROUTINE MAP_1_TO_3(L,J_BOUND,K_BOUND,I,J,K)
      IMPLICIT NONE
      INTEGER, INTENT(OUT)  :: I,J,K
      INTEGER, INTENT(IN)   :: L, J_BOUND, K_BOUND
      INTEGER               :: L_RUN

      L_RUN = L
      I = L_RUN/(J_BOUND*(K_BOUND+1)+K_BOUND+1)
      L_RUN = L_RUN - I*((J_BOUND*(K_BOUND+1)+K_BOUND+1))
      J = L_RUN/(K_BOUND+1)
      L_RUN = L_RUN - J*(K_BOUND+1)
      K  = L_RUN

      END SUBROUTINE MAP_1_TO_3


C     
C     Functionality to handling grid
C     

      SUBROUTINE WRITE_GOOD_HEL(STREAM_ID)
      IMPLICIT NONE
      INCLUDE 'maxamps.inc'
      INTEGER STREAM_ID
      INTEGER                 NCOMB
      PARAMETER (             NCOMB=16)
      LOGICAL GOODHEL(NCOMB, MAXSPROC)
      INTEGER NTRY(MAXSPROC)
      COMMON/BLOCK_GOODHEL/NTRY,GOODHEL
      WRITE(STREAM_ID,*) GOODHEL
      RETURN
      END


      SUBROUTINE READ_GOOD_HEL(STREAM_ID)
      IMPLICIT NONE
      INCLUDE 'genps.inc'
      INCLUDE 'maxamps.inc'
      INTEGER STREAM_ID
      INTEGER                 NCOMB
      PARAMETER (             NCOMB=16)
      LOGICAL GOODHEL(NCOMB, MAXSPROC)
      INTEGER NTRY(MAXSPROC)
      COMMON/BLOCK_GOODHEL/NTRY,GOODHEL
      READ(STREAM_ID,*) GOODHEL
      NTRY(:) = MAXTRIES + 1
      RETURN
      END

      SUBROUTINE INIT_GOOD_HEL()
      IMPLICIT NONE
      INCLUDE 'maxamps.inc'
      INTEGER                 NCOMB
      PARAMETER (             NCOMB=16)
      LOGICAL GOODHEL(NCOMB, MAXSPROC)
      INTEGER NTRY(MAXSPROC)
      INTEGER I,J

      GOODHEL(:,:) = .FALSE.
      NTRY(:) = 0
      END

      INTEGER FUNCTION GET_MAXSPROC()
      IMPLICIT NONE
      INCLUDE 'maxamps.inc'

      GET_MAXSPROC = MAXSPROC
      RETURN
      END




      SUBROUTINE PRINT_ZERO_AMP()

      CALL PRINT_ZERO_AMP1()
      RETURN
      END


      INTEGER FUNCTION GET_NHEL(HEL,PARTID)
      IMPLICIT NONE
      INTEGER HEL,PARTID
      WRITE(*,*) 'this type of pdf is not support with'
     $ //' group_subprocess=True. regenerate process with: set'
     $ //' group_subprocesses false'
      STOP 5
      RETURN
      END


      SUBROUTINE SELECT_COLOR(RCOL, JAMP2, ICONFIG, IPROC, ICOL)
      IMPLICIT NONE
      INCLUDE 'maxamps.inc'  ! for the definition of maxflow
      INCLUDE 'coloramps.inc'  ! set the coloramps
C     
C     argument IN
C     
      DOUBLE PRECISION RCOL  ! random number
      DOUBLE PRECISION JAMP2(0:MAXFLOW)
      INTEGER ICONFIG  ! amplitude selected
      INTEGER IPROC  ! matrix element selected
C     
C     argument OUT
C     
      INTEGER ICOL
C     
C     local
C     
      INTEGER NC  ! number of assigned color in jamp2
      LOGICAL IS_LC
      INTEGER MAXCOLOR
      DOUBLE PRECISION TARGETAMP(0:MAXFLOW)
      INTEGER I,J
      DOUBLE PRECISION XTARGET

      NC = INT(JAMP2(0))
      IS_LC = .TRUE.
      MAXCOLOR=0
      TARGETAMP(0) = 0D0
      IF(NC.EQ.0)THEN
        ICOL = 0
        RETURN
      ENDIF
      DO I=1,NC
        IF(ICOLAMP(I,ICONFIG,IPROC))THEN
          TARGETAMP(I) = TARGETAMP(I-1) + JAMP2(I)
        ELSE
          TARGETAMP(I) = TARGETAMP(I-1)
        ENDIF
      ENDDO

C     ensure that at least one leading color is different of zero if
C      not allow
C     all subleading color.
      IF (TARGETAMP(NC).EQ.0)THEN
        IS_LC = .FALSE.
        DO ICOL =1,NC
          TARGETAMP(ICOL) = JAMP2(ICOL)+TARGETAMP(ICOL-1)
        ENDDO
      ENDIF

      XTARGET=RCOL*TARGETAMP(NC)

      ICOL = 1
      DO WHILE (TARGETAMP(ICOL) .LT. XTARGET .AND. ICOL .LT. NC)
        ICOL = ICOL + 1
      ENDDO

      RETURN
      END

      SUBROUTINE GET_HELICITIES(IPROC, IHEL, NHEL)
      IMPLICIT NONE
      INCLUDE 'nexternal.inc'
      INTEGER IPROC
      INTEGER IHEL
      INTEGER NHEL(NEXTERNAL)
      INTEGER I
      INTEGER GET_NHEL1

      IF(IPROC.EQ.1)THEN
        DO I=1,NEXTERNAL
          NHEL(I) = GET_NHEL1(IHEL,I)
        ENDDO
      ENDIF

      RETURN
      END

