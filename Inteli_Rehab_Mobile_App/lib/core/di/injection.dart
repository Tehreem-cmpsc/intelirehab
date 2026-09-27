import 'package:get_it/get_it.dart';

import '../../features/auth/data/repositories/auth_repository_fake.dart';
import '../../features/auth/domain/repositories/auth_repository.dart';
import '../../features/auth/domain/usecases/login_usecase.dart';
import '../../features/auth/domain/usecases/register_usecase.dart';

import '../../features/clinic_selection/data/repositories/clinic_repository_fake.dart';
import '../../features/clinic_selection/domain/repositories/clinic_repository.dart';
import '../../features/clinic_selection/domain/usecases/get_clinics_usecase.dart';

import '../../features/physiotherapist_selection/data/repositories/physiotherapist_repository_fake.dart';
import '../../features/physiotherapist_selection/domain/repositories/physiotherapist_repository.dart';
import '../../features/physiotherapist_selection/domain/usecases/get_physiotherapists_usecase.dart';

final GetIt sl = GetIt.instance;

/// THE SWITCH — Change *RepositoryFake → *RepositoryImpl once Tehreem integrates real backend.
/// One line per feature, one file to change. Never rewrite a screen.
void setupInjection() {
  // ─── Auth ───────────────────────────────────────────────────────────────────
  sl.registerLazySingleton<AuthRepository>(() => AuthRepositoryFake());
  //   ↑ Swap to: AuthRepositoryImpl(sl()) once Tehreem is done with auth
  sl.registerFactory(() => LoginUsecase(sl()));
  sl.registerFactory(() => RegisterUsecase(sl()));

  // ─── Clinic Selection ────────────────────────────────────────────────────────
  sl.registerLazySingleton<ClinicRepository>(() => ClinicRepositoryFake());
  //   ↑ Swap to: ClinicRepositoryImpl(sl()) once Tehreem is done with clinics
  sl.registerFactory(() => GetClinicsUsecase(sl()));

  // ─── Physiotherapist Selection ───────────────────────────────────────────────
  sl.registerLazySingleton<PhysiotherapistRepository>(() => PhysiotherapistRepositoryFake());
  //   ↑ Swap to: PhysiotherapistRepositoryImpl(sl()) once Tehreem is done
  sl.registerFactory(() => GetPhysiotherapistsUsecase(sl()));
}
