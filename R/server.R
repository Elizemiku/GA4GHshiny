server <- function(data) {
    shinyServer(function(input, output, session) {
        
        # appearence
        shinyjs::html(selector = ".logo", html = paste(data$serverName,
            ifelse(data$host == data$serverName, "", paste("-", data$host))))
        
        # Dataset input list initialization
        choices <- data$datasets$id
        names(choices) <- data$datasets$name
        updateSelectizeInput(session, 'datasetId', choices = choices)
        shinyjs::enable("datasetId")

        # Gene symbol input list initialization
        if (!is.null(data$orgDb) && !is.na(data$orgDb)) {
            genomicFeatures <- list(
                "Genes" = genes,
                "Transcripts" = transcripts,
                "Exons" = exons,
                "CDS" = cds,
                "Promoters" = promoters
            )
            choices <- getGeneSymbols(data$orgDb)
            choices <- c("Select" = "Select", choices)
            updateSelectizeInput(session, "geneSymbol", choices = choices,
                selected = "Select", server = TRUE)

            shinyjs::enable("geneSymbol")
        }

        # Search button click action
        # This action will initialize Variant data table
        variants <- eventReactive(input$search,  {
            validate(
                need(!is.na(input$start), "Start should be informed."),
                need(!is.na(input$end), "End should be informed.")
            )
            if (input$genomicFeature != "Genes") {
                data$variants <- searchVariantsByGeneSymbol(
                    host = data$host,
                    variantSetId = data$variantSet$id,
                    seqlevelsStyle = data$seqlevelsStyle,
                    geneSymbol = input$geneSymbol, orgDb = data$orgDb,
                    txDb = data$txDb,
                    feature = genomicFeatures[[input$genomicFeature]])
                
            } else {
                data$variants <- searchVariants(
                    host = data$host,
                    variantSetId = data$variantSet$id,
                    referenceName = input$referenceName,
                    start = input$start,
                    end = input$end,
                    asVCF = FALSE)
            }
            table <- tidyVariants(data$variants)
            DT::datatable(table, selection = list(mode = "single", selected = 1,
                target = "row"), escape = FALSE,
                options = list(scrollX = TRUE))
        })

        output$dt.variants <- DT::renderDataTable({
            variants()
        })

        # Variant set input list initialization
        # It depends on Dataset input list selection
        observeEvent(input$datasetId, {
            if (input$datasetId == "")
                return()
            data <- initializeVariantSet(data, input$datasetId)
            choices <- data$variantSets$id
            names(choices) <- data$variantSets$name
            updateSelectizeInput(session, "variantSetId", choices = choices)
            shinyjs::enable("variantSetId")
        })

        # Reference Name input list initialization
        # It depends on Variant set input list selection
        observeEvent(input$variantSetId, {
            if (input$variantSetId == "")
                return()
            data <- initializeReferences(data, input$variantSetId)
            updateSelectizeInput(session, "referenceName",
                choices = data$references$name)
            shinyjs::enable("referenceName")
            shinyjs::enable("start")
            shinyjs::enable("end")
            shinyjs::enable("search")
        })

        # Gene symbol input list selection action
        # Reference Name, Start and End will change
        observeEvent(input$geneSymbol, {
            geneSymbol <- input$geneSymbol
            if (geneSymbol == "" || geneSymbol  == "Select")
                return()
            gene <- getGene(geneSymbol, data$orgDb, data$txDb)
            if (length(gene) == 0)
                return()
            if (length(gene) > 1) {
                warning(paste("Found more than one genomic location for",
                    gene, "gene. Using the first."))
                gene <- gene[1]
            }
            seqlevelsStyle(gene) <- data$seqlevelsStyle
            selected <- as.character(seqnames(gene))
            updateSelectizeInput(session, "referenceName", selected = selected)
            updateNumericInput(session, "start", value = start(gene))
            updateNumericInput(session, "end", value = end(gene))
            shinyjs::enable("genomicFeature")
        })
        
        output$beacon <- renderUI({
            if (is.null(input$dt.variants_rows_selected))
                return()
            data$variant <- data$variants[input$dt.variants_rows_selected, ]
            if (data$referenceSet$name == "NCBI37")
                data$referenceSet$name <- "GRCh37"
            src <- paste0("https://beacon-network.org:443/#/widget?",
                "rs=", data$referenceSet$name,
                "&chrom=", data$variant$referenceName,
                "&pos=", data$variant$start,
                "&ref=", data$variant$referenceBases,
                "&allele=", data$variant$alternateBases)
            tags$iframe(src = src, width = "100%", height = "500px")
        })
    })
}  