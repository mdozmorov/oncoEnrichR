
annotate_subcellular_compartments <-
  function(query_entrez,
           minimum_confidence = 1,
           show_cytosol = F,
           genedb = NULL,
           comppidb = NULL,
           go_gganatogram_map = NULL,
           transcript_xref = NULL,
           #oeDB = NULL,
           logger = NULL){

    stopifnot(!is.null(query_entrez))
    stopifnot(is.integer(query_entrez))
    stopifnot(!is.null(genedb))
    stopifnot(!is.null(logger))
    stopifnot(!is.null(transcript_xref))
    stopifnot(!is.null(comppidb))
    stopifnot(!is.null(go_gganatogram_map))
    stopifnot(is.numeric(minimum_confidence))
    validate_db_df(genedb, dbtype = "genedb")
    validate_db_df(comppidb, dbtype = "comppidb")
    validate_db_df(transcript_xref, dbtype = "transcript_xref")
    validate_db_df(go_gganatogram_map, dbtype = "go_gganatogram")

    log4r_info(logger, "ComPPI: retrieval of subcellular compartments for target set")

    uniprot_xref <- transcript_xref %>%
      dplyr::filter(.data$property == "uniprot_acc") %>%
      dplyr::rename(uniprot_acc = .data$value) %>%
      dplyr::select(.data$entrezgene, .data$uniprot_acc)

    target_genes <- data.frame(
      'entrezgene' = query_entrez, stringsAsFactors = F) %>%
      dplyr::left_join(uniprot_xref, by = "entrezgene") %>%
      dplyr::left_join(
        dplyr::select(genedb,
                      .data$symbol,
                      .data$entrezgene,
                      .data$genename),
        by = c("entrezgene"))

    target_compartments <- list()
    target_compartments[["all"]] <- data.frame()
    target_compartments[["grouped"]] <- data.frame()

    target_compartments_all <- as.data.frame(
      dplyr::inner_join(
        comppidb, target_genes, by = c("uniprot_acc")) %>%
        dplyr::filter(!is.na(.data$symbol)) %>%
        dplyr::filter(.data$confidence >= minimum_confidence)
    )

    if(nrow(target_compartments_all) > 0){
      target_compartments_all <- as.data.frame(
        target_compartments_all %>%
          #dplyr::select(-c(go_ontology,uniprot_acc)) %>%
          dplyr::left_join(
            go_gganatogram_map,
            by = "go_id") %>%
          dplyr::mutate(
            genelink =
              paste0("<a href ='http://www.ncbi.nlm.nih.gov/gene/",
                     .data$entrezgene,"' target='_blank'>", .data$symbol, "</a>")) %>%
          dplyr::mutate(
            compartment =
              paste0("<a href='http://amigo.geneontology.org/amigo/term/",
                     .data$go_id,"' target='_blank'>", .data$go_term, "</a>"))
      )

      target_compartments[["grouped"]] <- as.data.frame(
        target_compartments_all %>%
          dplyr::group_by(.data$go_id, .data$go_term, .data$compartment) %>%
          dplyr::summarise(
            targets = paste(unique(.data$symbol),
                            collapse = ", "),
            targetlinks = paste(unique(.data$genelink),
                                collapse = ", "),
            n = dplyr::n()) %>%
          dplyr::arrange(dplyr::desc(.data$n)) %>%
          dplyr::ungroup() %>%
          dplyr::select(-c(.data$go_id, .data$go_term))
      )

      target_compartments[["all"]] <- target_compartments_all %>%
        dplyr::select(-c(.data$entrezgene, .data$go_id,
                         .data$go_term, .data$genelink)) %>%
        dplyr::select(.data$symbol,
                      .data$genename,
                      .data$compartment,
                      dplyr::everything())

      n_genes <- length(unique(target_compartments_all$symbol))
      target_compartments[["anatogram"]] <-
        gganatogram::cell_key$cell %>%
        dplyr::select(-.data$value)

      anatogram_values <- as.data.frame(
        target_compartments_all %>%
          dplyr::select(.data$symbol, .data$ggcompartment) %>%
          dplyr::filter(!is.na(.data$ggcompartment)) %>%
          dplyr::distinct() %>%
          dplyr::group_by(.data$ggcompartment) %>%
          dplyr::summarise(n_comp = dplyr::n()) %>%
          dplyr::ungroup() %>%
          dplyr::mutate(value = round((.data$n_comp / n_genes) * 100, digits = 4)) %>%
          dplyr::rename(organ = .data$ggcompartment) %>%
          dplyr::select(.data$organ, .data$value)
      )

      target_compartments[["anatogram"]] <-
        target_compartments[["anatogram"]] %>%
        dplyr::left_join(anatogram_values, by = "organ") %>%
        dplyr::mutate(value = dplyr::if_else(
          is.na(.data$value), 0 , as.numeric(.data$value)))


    }
  return(target_compartments)


}
