#include "madx.h"

#if 0 // not used...
static double
get_beam_value(char* name, char* par)
  /* this function is used by fortran to get the parameters values of beams;
     returns parameter value "par" for beam of sequence "name" if present,
     where "name" may be "current", or "default", or the name of a sequence;
     else returns INVALID */
{
  struct command* cmd;
  mycpy(c_dum->c, name);
  mycpy(aux_buff->c, par);
  if (strcmp(c_dum->c, "current") == 0 && current_beam != NULL)
    return get_value("beam", par);
  else if (strcmp(c_dum->c, "default") == 0)
  {
    cmd = find_command("default_beam", beam_list);
    return command_par_value(aux_buff->c, cmd);
  }
  else if ((cmd = find_command(c_dum->c, beam_list)) != NULL)
    return command_par_value(aux_buff->c, cmd);
  else return INVALID;
}
#endif


static double
rfc_slope(void)
  /* calculates the accumulated "slope" of all cavities */
{
  double slope = zero, harmon, charge, pc;
  struct node* c_node = current_sequ->range_start;
  struct element* el;
  charge = command_par_value("charge", current_beam);
  pc = command_par_value("pc", current_beam);
  do
  {
    el = c_node->p_elem;
    if (strcmp(el->base_type->name, "rfcavity") == 0 &&
        (harmon = command_par_value("harmon", el->def)) > zero)
    {
      double volt = command_par_value("volt", el->def);
      double lag = command_par_value("lag", el->def);
      slope += ten_m_3 * charge * volt * harmon * cos(twopi * lag) / pc;
    }
    if (c_node == current_sequ->range_end) break;
    c_node = c_node->next;
  }
  while (c_node != NULL);
  return slope;
}

// public interface

void
exec_beam(struct in_cmd* cmd, int flag)
  /* chooses correct beam for beam definitions, upgrades, and resets */
{
  char* name;
  char name_def[] = "default_beam";
  struct command* keep_beam = current_beam;
  struct command_parameter_list* pl = cmd->clone->par;
  struct name_list* nl = cmd->clone->par_names;
  int pos = name_list_pos("sequence", nl);
  int bpos = name_list_pos("sequence", current_beam->par_names);

  if (nl->inform[pos]) {
    name = pl->parameters[pos]->string;
    if ((current_beam = find_command(name, beam_list)) == NULL) {
      set_defaults("beam"); 
      add_to_command_list(name, current_beam, beam_list, 0);
    }
  }
  else {
    name = name_def;
    current_beam = find_command(name, beam_list);
  }
  current_beam->par->parameters[bpos]->string = permbuff(name);
  current_beam->beam_def = 1;
  if (flag == 0) update_beam(cmd->clone); 
  else if (flag == 1)  set_defaults("beam"); // resbeam
  current_beam = keep_beam;
}

void
save_beam(struct sequence* sequ, FILE* file, int noexpr)
{
  struct command* comm;
  char beam_buff[AUX_LG];
  int i, def = 0;
  if ((comm = find_command(sequ->name, beam_list)) == NULL)
  {
    if (default_beam_saved == 0)
    {
      def = default_beam_saved = 1;
      comm = find_command("default_beam", beam_list);
    }
  }
  if (comm != NULL)
  {
    beam_buff[0] = '\0';
    strcat(beam_buff, "beam");
    for (i = 0; i < comm->par->curr; i++)
    {
      if (comm->par_names->inform[i])
      {
        if (strcmp(comm->par_names->names[i], "sequence") != 0
            || def == 0)
          export_comm_par(comm->par->parameters[i], beam_buff, noexpr);
      }
    }
    write_nice(beam_buff, file);
  }
}

void
show_beam(char* tok)
{
  struct command* comm;
  if (strlen(tok) > 5 && tok[4] == '%')
    comm = find_command(&tok[5], beam_list);
  else comm = find_command("default_beam", beam_list);
  if (comm != NULL) dump_command(comm);
}

void
update_beam(struct command* comm)
  /* calculates consistent values for modified beam data set.
     beam command values are evaluated in the order:
     particle->(mass+charge)
     energy->pc->gamma->beta->brho
     ex->exn
     ey->eyn
     current->npart
     where any item to the left takes precendence over the others;
     for ions, the input energy is multiplied by the charge, and the
  */
{
  struct name_list* nlc = comm->par_names;
  struct command_parameter_list* plc = comm->par;
  struct command_parameter_list* pl = current_beam->par;
  int pos, lp;
  char* name = blank;
  double energy = 0, beta = 0, gamma = 0, brho = 0, charge = 0, freq0 = 0, bcurrent = 0,
    npart = 0, mass = 0, pc = 0, circ = 0, arad = 0,
    ex, exn, ey, eyn, alfa;

  pos = name_list_pos("particle", nlc);
  if (nlc->inform[pos]) { /* parameter has been read */
    pl->parameters[pos]->string = name = plc->parameters[pos]->string;
    if ((lp = name_list_pos(name, defined_commands->list)) > -1) { // known particle
      mass = command_par_value("mass", defined_commands->commands[lp]);
      charge = command_par_value("charge", defined_commands->commands[lp]);
    }
    else { /* unknown particle, then mass and charge must be given as well */
      pos = name_list_pos("mass", nlc);
      if (nlc->inform[pos]) mass = command_par_value("mass", comm);
      else { // default is emass
	warning("emass given to unknown particle:", name);
	mass = get_variable("emass");
      }
      pos = name_list_pos("charge", nlc);
      if (nlc->inform[pos]) charge = command_par_value("charge", comm);
      else { //default is charge +1
	warning("charge +1 given to unknown particle:", name);
	charge = 1;
      }
    }
  }
  else if (nlc->inform[name_list_pos("mass", nlc)]) {
    mass = command_par_value("mass", comm);
    pl->parameters[pos]->string = name = permbuff("default");
    pos = name_list_pos("charge", nlc);
    if (nlc->inform[pos]) charge = command_par_value("charge", comm);
    else {
      warning("charge +1 given to user particle:", name);
      charge = 1;
    }
  }
  else name = pl->parameters[pos]->string; 

  if (strcmp(name, "ion") == 0) {
    pos = name_list_pos("mass", nlc);
    if (nlc->inform[pos]) mass = command_par_value("mass", comm);
    pos = name_list_pos("charge", nlc);
    if (nlc->inform[pos]) charge = command_par_value("charge", comm);
    else charge = command_par_value("charge", current_beam);
  }

  if (mass == zero) mass = command_par_value("mass", current_beam);

  if (charge == zero) charge = command_par_value("charge", current_beam);

  arad = ten_m_16 * charge * charge * get_variable("qelect") * clight * clight / mass;

  // energy related 
  if ((pos = name_list_pos("energy", nlc)) > -1 && nlc->inform[pos]) {
    energy = command_par_value("energy", comm);
    if (energy <= mass) fatal_error("energy must be","> mass");
    pc = sqrt(energy*energy - mass*mass);
    gamma = energy / mass;
    beta = pc / energy;
    brho = pc / ( fabs(charge) * clight * 1.e-9);
  }
  else if((pos = name_list_pos("pc", nlc)) > -1 && nlc->inform[pos]) {
    pc = command_par_value("pc", comm);
    energy = sqrt(pc*pc + mass*mass);
    gamma = energy / mass;
    beta = pc / energy;
    brho = pc / ( fabs(charge) * clight * 1.e-9);
  }
  else if((pos = name_list_pos("gamma", nlc)) > -1 && nlc->inform[pos]) {
    if ((gamma = command_par_value("gamma", comm)) <= one) fatal_error("gamma must be","> 1");
    energy = gamma * mass;
    pc = sqrt(energy*energy - mass*mass);
    beta = pc / energy;
    brho = pc / ( fabs(charge) * clight * 1.e-9); 
  }
  else if((pos = name_list_pos("beta", nlc)) > -1 && nlc->inform[pos]) {
    if ((beta = command_par_value("beta", comm)) >= one) fatal_error("beta must be","< 1");
    gamma = one / sqrt(one - beta*beta);
    energy = gamma * mass;
    pc = sqrt(energy*energy - mass*mass);
    brho = pc / ( fabs(charge) * clight * 1.e-9);
  }
  else if((pos = name_list_pos("brho", nlc)) > -1 && nlc->inform[pos]) {
    if ((brho = command_par_value("brho", comm)) < zero) fatal_error("brho must be","> 0");    
    pc = brho * fabs(charge) * clight * 1.e-9;
    energy = sqrt(pc*pc + mass*mass);
    gamma = energy / mass;
    beta = pc / energy;
  }
  else {
    energy = command_par_value("energy", current_beam);
    if (energy <= mass) fatal_error("energy must be","> mass");
    pc = sqrt(energy*energy - mass*mass);
    gamma = energy / mass;
    beta = pc / energy;
    brho = pc / ( fabs(charge) * clight * 1.e-9);
  }

  // emittance related
  // 2015-Mar-11  15:27:31  ghislain: changed emittance definition: 
  //                        was exn = ex * 4 * beta * gamma 
  if (nlc->inform[name_list_pos("ex", nlc)]) {
    ex = command_par_value("ex", comm);
    exn = ex * beta * gamma;
  }
  else if (nlc->inform[name_list_pos("exn", nlc)]) {
    exn = command_par_value("exn", comm);
    ex = exn / (beta * gamma);
  }
  else {
    ex = command_par_value("ex", current_beam);
    exn = ex * beta * gamma;
  }

  if (nlc->inform[name_list_pos("ey", nlc)]) {
    ey = command_par_value("ey", comm);
     eyn = ey * beta * gamma;
  }
  else if (nlc->inform[name_list_pos("eyn", nlc)]) {
    eyn = command_par_value("eyn", comm);
    ey = eyn / (beta * gamma);
  }
  else {
    ey = command_par_value("ey", current_beam);
    eyn = ey * beta * gamma;
  }

  alfa = one / (gamma * gamma);

  // circumference related
  if (nlc->inform[name_list_pos("circ", nlc)]) {
    circ = command_par_value("circ", comm);
    if (circ > zero) freq0 = (beta * clight) / (ten_p_6 * circ);
    store_comm_par_value("freq0", freq0, current_beam);
    store_comm_par_value("circ", circ, current_beam);
  }
  else if (nlc->inform[name_list_pos("freq0", nlc)]) {
    freq0 = command_par_value("freq0", comm);
    if (freq0 > zero) circ = (beta * clight) / (ten_p_6 * freq0);
    store_comm_par_value("freq0", freq0, current_beam);
    store_comm_par_value("circ", circ, current_beam);
  }
  
  // intensity related
  if (nlc->inform[name_list_pos("bcurrent", nlc)]) {
    bcurrent = command_par_value("bcurrent", comm);
    if (bcurrent > zero && freq0 > zero)
      npart = bcurrent / (beta * freq0 * ten_p_6 * get_variable("qelect"));
    else if (nlc->inform[name_list_pos("npart", nlc)]) {
      npart = command_par_value("npart", comm);
      bcurrent = npart * beta * freq0 * ten_p_6 * get_variable("qelect");
    }
  }
  else if (nlc->inform[name_list_pos("npart", nlc)]) {
    npart = command_par_value("npart", comm);
    bcurrent = npart * beta * freq0 * ten_p_6 * get_variable("qelect");
  }

  pos = name_list_pos("bunched", nlc);
  if (nlc->inform[pos])
    pl->parameters[pos]->double_value = plc->parameters[pos]->double_value;

  pos = name_list_pos("radiate", nlc);
  if (nlc->inform[pos])
    pl->parameters[pos]->double_value = plc->parameters[pos]->double_value;
  
  pos = name_list_pos("et", nlc);
  if (nlc->inform[pos])
    pl->parameters[pos]->double_value = plc->parameters[pos]->double_value;

  pos = name_list_pos("sigt", nlc);
  if (nlc->inform[pos])
    pl->parameters[pos]->double_value = plc->parameters[pos]->double_value;

  pos = name_list_pos("sige", nlc);
  if (nlc->inform[pos])
    pl->parameters[pos]->double_value = plc->parameters[pos]->double_value;

  pos = name_list_pos("kbunch", nlc);
  if (nlc->inform[pos])
    pl->parameters[pos]->double_value = plc->parameters[pos]->double_value;

  pos = name_list_pos("bv", nlc);
  if (nlc->inform[pos])
    pl->parameters[pos]->double_value = plc->parameters[pos]->double_value;

  pos = name_list_pos("pdamp", nlc);
  if (nlc->inform[pos])
    copy_double(plc->parameters[pos]->double_array->a, pl->parameters[pos]->double_array->a, 3);

  store_comm_par_value("mass", mass, current_beam);
  store_comm_par_value("charge", charge, current_beam);
  store_comm_par_value("energy", energy, current_beam);
  store_comm_par_value("pc", pc, current_beam);
  store_comm_par_value("gamma", gamma, current_beam);
  store_comm_par_value("beta", beta, current_beam);
  store_comm_par_value("brho", brho, current_beam);
  store_comm_par_value("ex", ex, current_beam);
  store_comm_par_value("exn", exn, current_beam);
  store_comm_par_value("ey", ey, current_beam);
  store_comm_par_value("eyn", eyn, current_beam);
  store_comm_par_value("npart", npart, current_beam);
  store_comm_par_value("bcurrent", bcurrent, current_beam);
  store_comm_par_value("alfa", alfa, current_beam);
  store_comm_par_value("arad", arad, current_beam);
}

void
adjust_beam(void)
  /* adjusts beam parameters to current beta, gamma, bcurrent, npart */
{
  struct name_list* nl = current_beam->par_names;
  double circ = one, freq0, alfa, beta, gamma, bcurrent = zero, npart = 0;

  if (current_sequ != NULL && sequence_length(current_sequ) != zero)
    circ = current_sequ->length;

  beta = command_par_value("beta", current_beam);
  gamma = command_par_value("gamma", current_beam);
  alfa = one / (gamma * gamma);

  freq0 = (beta * clight * ten_m_6) / circ;

  if (nl->inform[name_list_pos("bcurrent", nl)] &&
      (bcurrent = command_par_value("bcurrent", current_beam)) > zero)
    npart = bcurrent / (freq0 * ten_p_6 * get_variable("qelect"));
  else if (nl->inform[name_list_pos("npart", nl)] &&
           (npart = command_par_value("npart", current_beam)) > zero)
    bcurrent = npart * freq0 * ten_p_6 * get_variable("qelect");

  store_comm_par_value("alfa", alfa, current_beam);
  store_comm_par_value("freq0", freq0, current_beam);
  store_comm_par_value("circ", circ, current_beam);
  store_comm_par_value("npart", npart, current_beam);
  store_comm_par_value("bcurrent", bcurrent, current_beam);
}

int
attach_beam(struct sequence* sequ)
  /* attaches the beam belonging to the current sequence */
{
  if (!sequ || (current_beam = find_command(sequ->name, beam_list)) == NULL)
    current_beam = find_command("default_beam", beam_list);
  return current_beam->beam_def;
}

void
adjust_probe(double delta_p)
  /* adjusts beam parameters to the current deltap */
{
  double etas, slope, qs, fact, tmp, ds;
  double alfa, beta, gamma, dtbyds, circ, freq0; 
  double betas, gammas, et, sigt, sige;

  et = command_par_value("et", current_beam);
  sigt = command_par_value("sigt", current_beam);
  sige = command_par_value("sige", current_beam);
  beta = command_par_value("beta", current_beam);
  gamma = command_par_value("gamma", current_beam);
  circ = command_par_value("circ", current_beam);

  /* assume oneturnmap and disp0 already computed (see pro_twiss and pro_emit) */ 
  ds = oneturnmat[4 + 6*5]; // uses disp0[5] = 1 -> dp/p = 1
  for (int j=0; j < 4; j++) ds += oneturnmat[4 + 6*j] * disp0[j];

  tmp = - beta * beta * ds / circ;
  freq0 = (beta * clight * ten_m_6) / (circ * (one + tmp * delta_p));
  etas = beta * gamma * (one + delta_p);
  gammas = sqrt(one + etas * etas);
  betas = etas / gammas;
  tmp = - betas * betas * ds / circ;
  alfa = one / (gammas * gammas) + tmp;
  dtbyds = delta_p * tmp / betas;

// LD: 2016.02.16
  if (get_option("debug"))
    printf("updating probe_beam for deltap=%g => ds=%23.18g\n"
           "  parameters: freq0=%23.18g, alfa=%23.18g\n"
           "              beta=%23.18g, gamma=%23.18g, dtbyds=%23.18g\n",
           delta_p, ds, freq0, alfa, betas, gammas, dtbyds);

  store_comm_par_value("freq0", freq0, probe_beam);
  store_comm_par_value("alfa", alfa, probe_beam);
  store_comm_par_value("beta", betas, probe_beam);
  store_comm_par_value("gamma", gammas, probe_beam);
  store_comm_par_value("dtbyds", dtbyds, probe_beam);
  store_comm_par_value("deltap", delta_p, probe_beam);

  slope = -rfc_slope();
  qs = sqrt(fabs((tmp * slope) / (twopi * betas)));

  if (qs != zero) {
    fact = (tmp * circ) / (twopi * qs);
    if (et > zero) {
      sigt = sqrt(fabs(et * fact));
      sige = sqrt(fabs(et / fact));
    }
    else if (sigt > zero) {
      sige = sigt / fact;
      et = sige * sigt;
    }
    else if (sige > zero) {
      sigt = sige * fact;
      et = sige * sigt;
    }
  }

  if (sigt < ten_m_15) {
    put_info("Zero value of SIGT", "replaced by 1.");
    sigt = one;
  }
  
  if (sige < ten_m_15) {
    put_info("Zero value of SIGE", "replaced by 1/1000.");
    sigt = ten_m_3;
  }
  
  store_comm_par_value("qs", qs, probe_beam);
  store_comm_par_value("et", et, probe_beam);
  store_comm_par_value("sigt", sigt, probe_beam);
  store_comm_par_value("sige", sige, probe_beam);
}

void
adjust_rfc(void)
{
  /* adjusts rfc frequency to given harmon number */
  double freq0, harmon, freq;
  int i;
  struct element* el;
  freq0 = command_par_value("freq0", probe_beam);
  for (i = 0; i < current_sequ->cavities->curr; i++)
  {
    el = current_sequ->cavities->elem[i];
    if ((harmon = command_par_value("harmon", el->def)) > zero)
    {
      freq = freq0 * harmon;
      store_comm_par_value("freq", freq, el->def);
    }
  }
}

void
print_rfc(void)
  /* prints the rf cavities present in sequ */
{
  double freq0, harmon, freq;
  int i, n = current_sequ->cavities->curr;
  struct element* el;

  if (n == 0) return;

  freq0 = command_par_value("freq0", probe_beam);
  printf("\n RF system: \n");
  printf(v_format(" %S %NFs %NFs %NFs %NFs %NFs\n"),
         "Cavity","length[m]","voltage[MV]","lag","freq[MHz]","harmon");

  for (i = 0; i < n; i++) {
    el = current_sequ->cavities->elem[i];
    if ((harmon = el_par_value("harmon", el)) > zero) {
      freq = freq0 * harmon;
      printf(v_format(" %S %F %F %F %F %F\n"),
             el->name, el->length, el_par_value("volt", el),
             el_par_value("lag", el), freq, harmon);
    }
  }
}

void
print_probe(void)
{
  char tmp[NAME_L], trad[4];
  double alfa = get_value("probe", "alfa");
  double freq0 = get_value("probe", "freq0");
  double gamma = get_value("probe", "gamma");
  double beta = get_value("probe", "beta");
  double circ = get_value("probe", "circ");
  double bcurrent = get_value("probe", "bcurrent");
  double npart = get_value("probe", "npart");
  double energy = get_value("probe", "energy");
  int kbunch = get_value("probe", "kbunch");
  int rad = get_value("probe", "radiate");
  double gamtr = zero, t0 = zero, eta;

  get_string("probe", "particle", tmp);
  if (rad) strcpy(trad, "T");
  else     strcpy(trad, "F");
  if (alfa > zero) gamtr = sqrt(one / alfa);
  else if (alfa < zero) gamtr = sqrt(-one / alfa);
  if (freq0 > zero) t0 = one / freq0;
  eta = alfa - one / (gamma*gamma);
  puts(" ");
  printf(" Global parameters for %ss, radiate = %s:\n\n", tmp, trad);
  // 2015-Apr-15  15:27:15  ghislain: proposal for more elegant statement avoiding the strcpy to extra variable
  // printf(" Global parameters for %ss, radiate = %s:\n\n", tmp, rad ? "true" : "false"); 
  printf(v_format(" C         %F m          f0        %F MHz\n"),circ, freq0);
  printf(v_format(" T0        %F musecs     alfa      %F \n"), t0, alfa);
  printf(v_format(" eta       %F            gamma(tr) %F \n"), eta, gamtr);
  printf(v_format(" Bcurrent  %F A/bunch    Kbunch    %I \n"), bcurrent, kbunch);
  printf(v_format(" Npart     %F /bunch     Energy    %F GeV \n"), npart,energy);
  printf(v_format(" gamma     %F            beta      %F\n"), gamma, beta);
}

