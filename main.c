#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <time.h>
#include <ctype.h>

#define MAX_PATH_LEN 512
#define MAX_LOG_SIZE 65536
#define MAX_FIELD_LEN 256
#define SOGLIA_BATTERIA 80
#define SOGLIA_SSD 75

typedef struct {
    const char *nome;
    char stato[3];     /* "OK" o "KO" */
    char note[128];    /* descrizione del problema, se KO */
} Periferica;

void get_exe_dir(char *dir, size_t size, const char *argv0) {
    strncpy(dir, argv0, size - 1);
    dir[size - 1] = '\0';
    char *last = strrchr(dir, '\\');
    if (!last) last = strrchr(dir, '/');
    if (last) *(last + 1) = '\0';
    else strcpy(dir, ".\\");
}

void esegui_bat(const char *path) {
    char cmd[MAX_PATH_LEN + 4];
    snprintf(cmd, sizeof(cmd), "\"%s\"", path);
    system(cmd);
}

int leggi_file(const char *path, char *buffer, size_t bufsize) {
    FILE *f = fopen(path, "r");
    if (!f) return 0;
    size_t letti = fread(buffer, 1, bufsize - 1, f);
    buffer[letti] = '\0';
    fclose(f);
    return 1;
}

/* Cerca tutte le occorrenze di "marker" seguite da "NN%" e restituisce
 * il valore minimo trovato. Ritorna -1 se non trova nulla. */
int estrai_percentuale_minima(const char *testo, const char *marker) {
    int minimo = -1;
    const char *p = testo;
    size_t marker_len = strlen(marker);
    while ((p = strstr(p, marker)) != NULL) {
        p += marker_len;
        int val = atoi(p);
        if (val > 0 || (val == 0 && isdigit((unsigned char)*p))) {
            if (minimo == -1 || val < minimo) minimo = val;
        }
        p += 1;
    }
    return minimo;
}

/* Estrae il testo dopo la prima occorrenza di "marker" fino a fine riga */
void estrai_valore_testo(const char *testo, const char *marker, char *output, size_t output_size) {
    const char *p = strstr(testo, marker);
    strcpy(output, "Non disponibile");
    if (!p) return;
    p += strlen(marker);
    while (*p == ' ') p++;
    size_t i = 0;
    while (*p && *p != '\r' && *p != '\n' && i < output_size - 1) {
        output[i++] = *p++;
    }
    output[i] = '\0';
}

int main(int argc, char *argv[]) {
    char exe_dir[MAX_PATH_LEN];
    char operatore[128];
    char path_bat1[MAX_PATH_LEN], path_bat2[MAX_PATH_LEN], path_bat3[MAX_PATH_LEN];
    char path_log[MAX_PATH_LEN], path_report[MAX_PATH_LEN];
    char log_content[MAX_LOG_SIZE];
    char difetti[4096] = "";
    time_t now;
    struct tm *tm_info;
    char data_str[64];
    char data_file[64];

    char seriale[MAX_FIELD_LEN], tipo_pc[MAX_FIELD_LEN], cpu_model[MAX_FIELD_LEN];

    get_exe_dir(exe_dir, sizeof(exe_dir), argv[0]);
    snprintf(path_bat1, sizeof(path_bat1), "%ssystem_report.bat", exe_dir);
    snprintf(path_bat2, sizeof(path_bat2), "%speripheral_test.bat", exe_dir);
    snprintf(path_bat3, sizeof(path_bat3), "%swin_update.bat", exe_dir);
    snprintf(path_log, sizeof(path_log), "%ssystem_report_output.txt", exe_dir);

    printf("=== PRESTIGE GROUP SRL - COLLAUDO PC ===\n\n");
    printf("Nome operatore: ");
    fgets(operatore, sizeof(operatore), stdin);
    operatore[strcspn(operatore, "\n")] = '\0';

    /* ---------- STEP 1: Report di sistema ---------- */
    printf("\n[1/3] Avvio system_report.bat (potrebbe comparire richiesta UAC)...\n");
    esegui_bat(path_bat1);

    int batteria_pct = -1, ssd_pct = -1;
    strcpy(seriale, "Non disponibile");
    strcpy(tipo_pc, "Non disponibile");
    strcpy(cpu_model, "Non disponibile");

    if (leggi_file(path_log, log_content, sizeof(log_content))) {
        batteria_pct = estrai_percentuale_minima(log_content, "Stato Batteria: ");
        ssd_pct = estrai_percentuale_minima(log_content, "Salute SSD: ");
        estrai_valore_testo(log_content, "Numero Seriale: ", seriale, sizeof(seriale));
        estrai_valore_testo(log_content, "Tipo PC: ", tipo_pc, sizeof(tipo_pc));
        estrai_valore_testo(log_content, "CPU: ", cpu_model, sizeof(cpu_model));
    } else {
        printf("ATTENZIONE: impossibile leggere %s\n", path_log);
    }

    printf("\nNumero Seriale: %s\n", seriale);
    printf("Tipo PC: %s\n", tipo_pc);
    printf("CPU: %s\n", cpu_model);
    printf("Risultato Batteria: %d%%\n", batteria_pct);
    printf("Risultato Salute SSD: %d%%\n", ssd_pct);

    if (batteria_pct == -1 || batteria_pct < SOGLIA_BATTERIA)
        strcat(difetti, "BATTERIA (STATO INFERIORE A 80%% O NON RILEVATA)\n");
    if (ssd_pct == -1 || ssd_pct < SOGLIA_SSD)
        strcat(difetti, "SSD (SALUTE INFERIORE A 75%% O NON RILEVATA)\n");

    /* ---------- STEP 2: Test periferiche ---------- */
    printf("\n[2/3] Avvio peripheral_test.bat (test manuale periferiche)...\n");
    esegui_bat(path_bat2);

    Periferica periferiche[] = {
        {"WiFi", "", ""}, {"Webcam", "", ""}, {"Microfono", "", ""}, {"Schermo (LCD)", "", ""},
        {"Tastiera", "", ""}, {"Trackpad", "", ""}, {"Mouse", "", ""}, {"Audio", "", ""}
    };
    int n_periferiche = sizeof(periferiche) / sizeof(periferiche[0]);

    printf("\nInserisci il risultato per ciascuna periferica (O = OK, K = difettosa):\n");
    for (int i = 0; i < n_periferiche; i++) {
        char risposta[8];
        do {
            printf("  %-16s: ", periferiche[i].nome);
            fgets(risposta, sizeof(risposta), stdin);
        } while (toupper((unsigned char)risposta[0]) != 'O' && toupper((unsigned char)risposta[0]) != 'K');

        if (toupper((unsigned char)risposta[0]) == 'O') {
            strcpy(periferiche[i].stato, "OK");
            periferiche[i].note[0] = '\0';
        } else {
            strcpy(periferiche[i].stato, "KO");

            char descrizione[128];
            printf("    -> Descrivi il problema riscontrato: ");
            fgets(descrizione, sizeof(descrizione), stdin);
            descrizione[strcspn(descrizione, "\n")] = '\0';
            if (strlen(descrizione) == 0) {
                strcpy(descrizione, "Nessuna descrizione fornita");
            }
            strncpy(periferiche[i].note, descrizione, sizeof(periferiche[i].note) - 1);
            periferiche[i].note[sizeof(periferiche[i].note) - 1] = '\0';

            char nome_maiusc[64];
            strncpy(nome_maiusc, periferiche[i].nome, sizeof(nome_maiusc) - 1);
            nome_maiusc[sizeof(nome_maiusc) - 1] = '\0';
            for (char *c = nome_maiusc; *c; c++) *c = toupper((unsigned char)*c);

            char note_maiusc[128];
            strncpy(note_maiusc, descrizione, sizeof(note_maiusc) - 1);
            note_maiusc[sizeof(note_maiusc) - 1] = '\0';
            for (char *c = note_maiusc; *c; c++) *c = toupper((unsigned char)*c);

            char buf[256];
            snprintf(buf, sizeof(buf), "%s DIFETTOSO/A - %s\n", nome_maiusc, note_maiusc);
            strcat(difetti, buf);
        }
    }

    /* ---------- STEP 3: Aggiornamento driver/Windows Update ---------- */
    printf("\n[3/3] Avvio win_update.bat (aggiornamento driver e Windows Update)...\n");
    esegui_bat(path_bat3);
    printf("Aggiornamenti completati.\n");

    /* ---------- Generazione report finale ---------- */
    time(&now);
    tm_info = localtime(&now);
    strftime(data_str, sizeof(data_str), "%d/%m/%Y %H:%M:%S", tm_info);
    strftime(data_file, sizeof(data_file), "%Y%m%d_%H%M%S", tm_info);

    snprintf(path_report, sizeof(path_report), "%sReport_Test_%s_%s.txt",
             exe_dir, operatore, data_file);

    FILE *report = fopen(path_report, "w");
    if (!report) {
        printf("ERRORE: impossibile creare il file di report.\n");
        return 1;
    }

    fprintf(report, "==========================================\n");
    fprintf(report, "PRESTIGE GROUP SRL - REPORT DI COLLAUDO PC\n");
    fprintf(report, "==========================================\n");
    fprintf(report, "Operatore: %s\n", operatore);
    fprintf(report, "Data/Ora:  %s\n\n", data_str);

    /* --- STATO SOFTWARE --- */
    fprintf(report, "==========================================\n");
    fprintf(report, "STATO SOFTWARE\n");
    fprintf(report, "==========================================\n");
    fprintf(report, "Aggiornamento driver e Windows Update: COMPLETATO\n\n");

    /* --- STATO HARDWARE --- */
    fprintf(report, "==========================================\n");
    fprintf(report, "STATO HARDWARE\n");
    fprintf(report, "==========================================\n");
    fprintf(report, "Numero Seriale: %s\n", seriale);
    fprintf(report, "Tipo PC: %s\n", tipo_pc);
    fprintf(report, "CPU: %s\n", cpu_model);
    fprintf(report, "Batteria: %d%% (soglia minima: %d%%)\n", batteria_pct, SOGLIA_BATTERIA);
    fprintf(report, "Salute SSD: %d%% (soglia minima: %d%%)\n\n", ssd_pct, SOGLIA_SSD);
    fprintf(report, "Dettaglio completo:\n%s\n\n", log_content);

    /* --- STATO PERIFERICHE --- */
    fprintf(report, "==========================================\n");
    fprintf(report, "STATO PERIFERICHE\n");
    fprintf(report, "==========================================\n");
    for (int i = 0; i < n_periferiche; i++) {
        if (strcmp(periferiche[i].stato, "KO") == 0) {
            fprintf(report, "%-16s: %s - %s\n", periferiche[i].nome, periferiche[i].stato, periferiche[i].note);
        } else {
            fprintf(report, "%-16s: %s\n", periferiche[i].nome, periferiche[i].stato);
        }
    }

    fprintf(report, "\n==========================================\n");
    fprintf(report, "DIFETTI RISCONTRATI:\n");
    fprintf(report, "==========================================\n");
    if (strlen(difetti) == 0) {
        fprintf(report, "NESSUN DIFETTO RISCONTRATO\n");
    } else {
        fprintf(report, "%s", difetti);
    }

    fclose(report);
    printf("\nReport salvato in: %s\n", path_report);

    printf("\nPremi INVIO per uscire...");
    getchar();
    return 0;
}
